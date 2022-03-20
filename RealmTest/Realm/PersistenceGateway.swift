//
//  PersistenceGateway.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Combine
import Foundation
import RealmSwift

final class PersistenceGateway: PersistenceGatewayProtocol {
    private let configuration: Realm.Configuration
	private let regularScheduler: AnySchedulerOf<DispatchQueue>
	private let listenScheduler: AnySchedulerOf<RunLoop>
    
    init(
		regularScheduler: AnySchedulerOf<DispatchQueue>,
		listenScheduler: AnySchedulerOf<RunLoop> = .main,
		configuration: Realm.Configuration = .init()
	) {
		self.regularScheduler = regularScheduler
		self.listenScheduler = listenScheduler
        self.configuration = configuration
    }
    
    private func realm<S: Scheduler>(scheduler: S) -> AnyPublisher<Realm, Error> {
        // Создание рилма в определенном потоке
        return Just((configuration, nil))
            .receive(on: scheduler)
            .tryMap(Realm.init)
            .eraseToAnyPublisher()
    }
    
    // MARK: Get
    
	func get<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<Entity?, Error> {
        return realm(scheduler: regularScheduler)
            .map { $0.objects(DBEntity.self) }
            .map { filterBlock($0).last.map(mapper) }
            .eraseToAnyPublisher()
    }
    
	func getArray<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<[Entity], Error> {
        return realm(scheduler: regularScheduler)
            .map { $0.objects(DBEntity.self) }
            .map { filterBlock($0) }
            .map { $0.map(mapper) }
            .eraseToAnyPublisher()
    }
    
    // MARK: Listen
    
	func listen<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<Entity, Error> {
        return realm(scheduler: listenScheduler)
            .map { $0.objects(DBEntity.self) } // Получает список объектов для типа
            .map { filterBlock($0) } // Фильтрует список объектов для получения только интересующего объекта
            .flatMap(\.collectionPublisher) // Наблюдает за изменением фильтрованных объектов. Работает даже, если объект не существовал на момент подписки
            .freeze()
            .receive(on: regularScheduler)
            .compactMap { $0.last } // Результат может содержать массив объектов, если поиск осуществлялся не по primary key, либо, если primary key нет вовсе.
                                    // Для обработки ситуации, когда нет primary key берется `last`, а не `first`
            .map(mapper)
            .eraseToAnyPublisher()
    }
	
	public func listenOrderedArrayChanges<RealmSource: Object, TargetDB: Object, TargetEntity>(
		_: RealmSource.Type,
		mapper: @escaping FromRealmMapper<TargetDB, TargetEntity>,
		keyPath: KeyPath<RealmSource, List<TargetDB>>,
		filterBlock: @escaping (Results<RealmSource>) -> Results<RealmSource>,
		comparator: @escaping (TargetEntity, TargetEntity) -> Bool
	) -> AnyPublisher<PersistenceChangeset<TargetEntity>, Error> {
		return realm(scheduler: listenScheduler)
			.map { $0.objects(RealmSource.self) }
			.flatMap {
				$0.collectionPublisher
					.filter { !$0.isEmpty }
					.prefix(1)
			}
			.compactMap { filterBlock($0).first }
			.map { $0[keyPath: keyPath] }
			.flatMap(\.collectionPublisher)
			.freeze()
			.receive(on: regularScheduler)
			.map { $0.map(mapper) }
			.diff(comparator: comparator)
			.eraseToAnyPublisher()
	}
	
	func listenOrderedArrayChanges<RealmSource: Object, TargetDB: Object, TargetEntity>(
		_ sourceType: RealmSource.Type,
		mapper: @escaping FromRealmMapper<TargetDB, TargetEntity>,
		keyPath: KeyPath<RealmSource, List<TargetDB>>,
		filterBlock: @escaping (Results<RealmSource>) -> Results<RealmSource>
	) -> AnyPublisher<PersistenceChangeset<TargetEntity>, Error> where TargetEntity: Equatable {
		listenOrderedArrayChanges(
			sourceType,
			mapper: mapper,
			keyPath: keyPath,
			filterBlock: filterBlock
		) { $0 == $1 }
	}
    
	func listenArray<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		range: Range<Int>?,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<[Entity], Error> {
        return realm(scheduler: listenScheduler)
            .map { $0.objects(DBEntity.self) }
			.map { filterBlock($0) }
            .flatMap(\.collectionPublisher)
            .freeze()
            .receive(on: regularScheduler)
            .map { results -> [DBEntity] in
                // Если range существует - получаем слайс из коллекции, иначе берём коллекцию целиком
                let slice = range.map { $0.clamped(to: 0..<results.count) }.map { Array(results[$0]) }
                return slice ?? Array(results)
            }
            .map { $0.map(mapper) }
            .eraseToAnyPublisher()
    }

    // MARK: Save
    
	func save<DBEntity: Object, Entity>(
		object: Entity,
		mapper: @escaping ToRealmMapper<DBEntity, Entity>,
		update: Realm.UpdatePolicy
	) -> AnyPublisher<Void, Error> {
        return realm(scheduler: regularScheduler)
            .tryMap { realm in
				let persistence = mapper(object)
				let hasPrimaryKey = persistence.objectSchema.primaryKeyProperty != nil
				
				try realm.safeWrite {
					hasPrimaryKey ? realm.add(persistence, update: update) : realm.add(persistence)
				}
				realm.refresh()
				
				return ()
            }
            .eraseToAnyPublisher()
    }
    
	func save<DBEntity: Object, Entity>(
		objects: [Entity],
		mapper: @escaping ToRealmMapper<DBEntity, Entity>,
		update: Realm.UpdatePolicy
	) -> AnyPublisher<Void, Error> {
        return realm(scheduler: regularScheduler)
            .tryMap { realm in
				let persistenceObjects = objects.map(mapper)
				let hasPrimaryKey = persistenceObjects.first?.objectSchema.primaryKeyProperty != nil
				
				try realm.safeWrite {
					hasPrimaryKey ? realm.add(persistenceObjects, update: update) : realm.add(persistenceObjects)
				}
				realm.refresh()
				
				return ()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: Delete
    
	func delete<DBEntity: Object>(_ type: DBEntity.Type, filterBlock: @escaping RealmFilter<DBEntity>) -> AnyPublisher<Void, Error> {
        return realm(scheduler: regularScheduler)
            .tryMap { realm in
				let objects = realm.objects(DBEntity.self)
				let toDelete = filterBlock(objects)
				
				try realm.write {
					realm.delete(toDelete)
				}
				
				return ()
            }
            .eraseToAnyPublisher()
    }
	
	func deleteAll() {
		guard let realm = try? Realm(configuration: configuration) else {
			return
		}
		
		try? realm.safeWrite {
			realm.deleteAll()
		}
	}
    
    // MARK: Action
    
    func updateAction(_ action: @escaping (Realm) throws -> Void) -> AnyPublisher<Void, Error> {
        return realm(scheduler: regularScheduler)
            .tryMap { realm in
				try realm.safeWrite {
					try action(realm)
				}
				realm.refresh()
            }
            .eraseToAnyPublisher()
    }
    
	func count<DBEntity: Object>(_ type: DBEntity.Type, filterBlock: @escaping RealmFilter<DBEntity>) -> AnyPublisher<Int, Error> {
        return realm(scheduler: regularScheduler)
            .map { $0.objects(DBEntity.self) }
            .compactMap { filterBlock($0).count }
            .eraseToAnyPublisher()
    }
}

extension Realm {
	func safeWrite(_ block: () throws -> Void) throws {
		if isInWriteTransaction {
			try block()
		} else {
			try write(block)
		}
	}
}
