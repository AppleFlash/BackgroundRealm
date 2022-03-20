//
//  PersistenceGatewayProtocol.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 15.06.2021.
//

import Foundation
import Combine
import RealmSwift

public typealias ToRealmMapper<DBEntity: Object, Entity> = (Entity) -> DBEntity
public typealias FromRealmMapper<DBEntity: Object, Entity> = (DBEntity) -> Entity
public typealias RealmFilter<DBEntity: Object> = (Results<DBEntity>) -> Results<DBEntity>

protocol PersistenceGatewayProtocol: AnyObject {
    /// Позволяет выполнять любое действие с рилмом. Все действия происходит в транзакции записи
	func updateAction(_ action: @escaping (Realm) throws -> Void) -> AnyPublisher<Void, Error>
    
	func get<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<Entity?, Error>
    
    /// Получает массив объектов из рилма
    /// - Parameters:
    ///   - mapper: маппер для конвертации объектов рилма в доменные объекты
    ///   - filterBlock: фильтр, который является основным инструментом поиска нужных элементов
    func getArray<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<[Entity], Error>
    
	func listen<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		filterBlock: @escaping RealmFilter<DBEntity>
	) -> AnyPublisher<Entity, Error>
    
    /// Наблюдает за изменением определенного массива объектов.
    /// Наблюдение будет валидно, даже, если объекты не существовали на момент начала наблюдение и появились после
    /// - Parameters:
    ///   - mapper: маппер для конвертации объектов рилма в доменные объекты
    ///   - range: можно указать интервал интересующих объектов
    ///   - filterBlock: фильтр, который является основным инструментом поиска нужных элементов
    func listenArray<DBEntity: Object, Entity>(
        mapper: @escaping FromRealmMapper<DBEntity, Entity>,
        range: Range<Int>?,
        filterBlock: @escaping RealmFilter<DBEntity>
    ) -> AnyPublisher<[Entity], Error>
	
	/// Наблюдает за изменением элементов в листе.
	/// Наблюдение будет валидно, даже, если объекты не существовали на момент начала наблюдение и появились после.
	/// На выходе получаем список изменений (вставка, удаление), состоящий из типа изменения, жлемента и/или порядокового индекса
	/// - Parameters:
	///   - sourceType: исходный тип - контейнер, содержащий лист
	///   - mapper: маппер для перевода элементов листа в доменные объекты
	///   - filterBlock: блок сначала позволяет получить нужный контейнер, фильтроваф, например, по идентификатору, а, далее получить нужный List
	///   - comparator: блок для сравнения объектов. На основе блока формируется список изменений
	func listenOrderedArrayChanges<RealmSource: Object, TargetDB: Object, TargetEntity>(
		_: RealmSource.Type,
		mapper: @escaping FromRealmMapper<TargetDB, TargetEntity>,
		keyPath: KeyPath<RealmSource, List<TargetDB>>,
		filterBlock: @escaping (Results<RealmSource>) -> Results<RealmSource>,
		comparator: @escaping (TargetEntity, TargetEntity) -> Bool
	) -> AnyPublisher<PersistenceChangeset<TargetEntity>, Error>
	
	/// Наблюдает за изменением элементов в листе.
	/// Наблюдение будет валидно, даже, если объекты не существовали на момент начала наблюдение и появились после.
	/// На выходе получаем список изменений (вставка, удаление), состоящий из типа изменения, жлемента и/или порядокового индекса.
	/// - Parameters:
	///   - sourceType: исходный тип - контейнер, содержащий лист
	///   - mapper: маппер для перевода элементов листа в доменные объекты
	///   - filterBlock: блок сначала позволяет получить нужный контейнер, фильтроваф, например, по идентификатору, а, далее получить нужный List
	func listenOrderedArrayChanges<RealmSource: Object, TargetDB: Object, TargetEntity>(
		_: RealmSource.Type,
		mapper: @escaping FromRealmMapper<TargetDB, TargetEntity>,
		keyPath: KeyPath<RealmSource, List<TargetDB>>,
		filterBlock: @escaping (Results<RealmSource>) -> Results<RealmSource>
	) -> AnyPublisher<PersistenceChangeset<TargetEntity>, Error> where TargetEntity: Equatable
    
    /// Сохраняет объект в базу
    /// - Parameters:
    ///   - object: объект для сохранения
    ///   - mapper: маппер для конвертации доменного объекта в рилм
	func save<DBEntity: Object, Entity>(
		object: Entity,
		mapper: @escaping ToRealmMapper<DBEntity, Entity>,
		update: Realm.UpdatePolicy
	) -> AnyPublisher<Void, Error>
    
    /// Сохраняет массив объектов в базу
    /// - Parameters:
    ///   - objects: объект для сохранения
    ///   - mapper: маппер для конвертации доменных объектов в рилм
    func save<DBEntity: Object, Entity>(
		objects: [Entity],
		mapper: @escaping ToRealmMapper<DBEntity, Entity>,
		update: Realm.UpdatePolicy
	) -> AnyPublisher<Void, Error>
    
    /// Удаляет объект, соответствующий фильтру, из базы
    /// - Parameters:
    ///   - type: тип удаляемого объекта
    ///   - deleteHandler: поиск удаляемого объекта
	func delete<DBEntity: Object>(_ type: DBEntity.Type, filterBlock: @escaping RealmFilter<DBEntity>) -> AnyPublisher<Void, Error>
	
	/// Возвращает количество объектов в базе, удовлетворяющих фильтру
	/// - Parameters:
	///   - type: тип объектов для определения количества
	///   - filterBlock: блок фильтрации
	func count<DBEntity: Object>(_ type: DBEntity.Type, filterBlock: @escaping RealmFilter<DBEntity>) -> AnyPublisher<Int, Error>
	
	/// Очищает рилм
	func deleteAll()
}

extension PersistenceGatewayProtocol {
	func get<DBEntity: Object, Entity>(mapper: @escaping FromRealmMapper<DBEntity, Entity>) -> AnyPublisher<Entity?, Error> {
        get(mapper: mapper) { $0 }
    }
    
	func getArray<DBEntity: Object, Entity>(mapper: @escaping FromRealmMapper<DBEntity, Entity>) -> AnyPublisher<[Entity], Error> {
        getArray(mapper: mapper) { $0 }
    }
    
	func listen<DBEntity: Object, Entity>(mapper: @escaping FromRealmMapper<DBEntity, Entity>) -> AnyPublisher<Entity, Error> {
        listen(mapper: mapper) { $0 }
    }
    
	func listenArray<DBEntity: Object, Entity>(
		mapper: @escaping FromRealmMapper<DBEntity, Entity>,
		range: Range<Int>? = nil
	) -> AnyPublisher<[Entity], Error> {
        listenArray(mapper: mapper, range: range) { $0 }
    }
    
	func save<DBEntity: Object, Entity>(
		object: Entity,
		mapper: @escaping ToRealmMapper<DBEntity, Entity>,
		update: Realm.UpdatePolicy = .all
	) -> AnyPublisher<Void, Error> {
        save(object: object, mapper: mapper, update: update)
    }
    
	func save<DBEntity: Object, Entity>(
		objects: [Entity],
		mapper: @escaping ToRealmMapper<DBEntity, Entity>,
		update: Realm.UpdatePolicy = .all
	) -> AnyPublisher<Void, Error> {
        save(objects: objects, mapper: mapper, update: update)
    }
	
	func count<DBEntity: Object>(_ type: DBEntity.Type) -> AnyPublisher<Int, Error> {
		count(type) { $0 }
	}
}
