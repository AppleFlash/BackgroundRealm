//
//  PersistenceGatewayProtocol.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 15.06.2021.
//

import Foundation
import Combine
import RealmSwift

protocol PersistenceGatewayProtocol: AnyObject {
    /// Позволяет выполнять любое действие с рилмом. Все действия происходит в транзакции записи
	func updateAction(_ action: @escaping (Realm) throws -> Void) -> AnySinglePublisher<Void, Error>
    
    /// Получает объект из рилма
    /// - Parameters:
    ///   - mapper: маппер для конвертации объекта рилма в доменный объект
    ///   - filterBlock: фильтр, который является основным инструментом поиска нужного элемента
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<M.DomainModel?, Error>
    
    /// Получает массив объектов из рилма
    /// - Parameters:
    ///   - mapper: маппер для конвертации объектов рилма в доменные объекты
    ///   - filterBlock: фильтр, который является основным инструментом поиска нужных элементов
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error>
    
    /// Наблюдает за изменением объекта. Наблюдение будет валидно, даже, если объект не существовал на момент начала наблюдение и появился после
    /// - Parameters:
    ///   - mapper: маппер для конвертации объекта рилма в доменный объект
    ///   - filterBlock: фильтр, который является основным инструментом поиска нужного элемента
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error>
    
    /// Наблюдает за изменением определенного массива объектов.
    /// Наблюдение будет валидно, даже, если объекты не существовали на момент начала наблюдение и появились после
    /// - Parameters:
    ///   - mapper: маппер для конвертации объектов рилма в доменные объекты
    ///   - range: можно указать интервал интересующих объектов
    ///   - filterBlock: фильтр, который является основным инструментом поиска нужных элементов
    func listenArray<M: PersistenceToDomainMapper>(
        mapper: M,
        range: Range<Int>?,
        filterBlock: @escaping GetResultBlock<M>
    ) -> AnyPublisher<[M.DomainModel], Error>
	
	/// Наблюдает за изменением элементов в листе.
	/// Наблюдение будет валидно, даже, если объекты не существовали на момент начала наблюдение и появились после.
	/// На выходе получаем список изменений (вставка, удаление), состоящий из типа изменения, жлемента и/или порядокового индекса
	/// - Parameters:
	///   - sourceType: исходный тип - контейнер, содержащий лист
	///   - mapper: маппер для перевода элементов листа в доменные объекты
	///   - filterBlock: блок сначала позволяет получить нужный контейнер, фильтроваф, например, по идентификатору, а, далее получить нужный List
	///   - comparator: блок для сравнения объектов. На основе блока формируется список изменений
    func listenOrderedArrayChanges<Source: PersistenceToDomainMapper, Target: PersistenceToDomainMapper>(
        _ sourceType: Source.Type,
        mapper: Target,
        filterBlock: @escaping (Results<Source.PersistenceModel>) -> List<Target.PersistenceModel>?,
		comparator: @escaping (Target.DomainModel, Target.DomainModel) -> Bool
	) -> AnyPublisher<PersistenceChangeset<Target.DomainModel>, Error>
	
	/// Наблюдает за изменением элементов в листе.
	/// Наблюдение будет валидно, даже, если объекты не существовали на момент начала наблюдение и появились после.
	/// На выходе получаем список изменений (вставка, удаление), состоящий из типа изменения, жлемента и/или порядокового индекса.
	/// - Parameters:
	///   - sourceType: исходный тип - контейнер, содержащий лист
	///   - mapper: маппер для перевода элементов листа в доменные объекты
	///   - filterBlock: блок сначала позволяет получить нужный контейнер, фильтроваф, например, по идентификатору, а, далее получить нужный List
	func listenOrderedArrayChanges<Source: PersistenceToDomainMapper, Target: PersistenceToDomainMapper>(
		_ sourceType: Source.Type,
		mapper: Target,
		filterBlock: @escaping (Results<Source.PersistenceModel>) -> List<Target.PersistenceModel>?
	) -> AnyPublisher<PersistenceChangeset<Target.DomainModel>, Error> where Target.DomainModel: Equatable
    
    /// Сохраняет объект в базу
    /// - Parameters:
    ///   - object: объект для сохранения
    ///   - mapper: маппер для конвертации доменного объекта в рилм
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M, update: Realm.UpdatePolicy) -> AnySinglePublisher<Void, Error>
    
    /// Сохраняет массив объектов в базу
    /// - Parameters:
    ///   - objects: объект для сохранения
    ///   - mapper: маппер для конвертации доменных объектов в рилм
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M, update: Realm.UpdatePolicy) -> AnySinglePublisher<Void, Error>
    
    /// Удаляет объект, соответствующий фильтру, из базы
    /// - Parameters:
    ///   - type: тип удаляемого объекта
    ///   - deleteHandler: поиск удаляемого объекта
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnySinglePublisher<Void, Error>
    
    /// Возвращает количество объектов в базе, удовлетворяющих фильтру
    /// - Parameters:
    ///   - type: тип объектов для определения количества
    ///   - filterBlock: блок фильтрации
    func count<T: ObjectToPersistenceMapper>(_ type: T.Type, filterBlock: @escaping SaveResultBlock<T>) -> AnySinglePublisher<Int, Error>
	
	/// Очищает рилм
	func deleteAll()
}

extension PersistenceGatewayProtocol {
    func get<M: PersistenceToDomainMapper>(mapper: M) -> AnySinglePublisher<M.DomainModel?, Error> {
        get(mapper: mapper) { $0 }
    }
    
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error> {
        getArray(mapper: mapper) { $0 }
    }
    
    func listen<M: PersistenceToDomainMapper>(mapper: M) -> AnyPublisher<M.DomainModel, Error> {
        listen(mapper: mapper) { $0 }
    }
    
    func listenArray<M: PersistenceToDomainMapper>(mapper: M, range: Range<Int>? = nil) -> AnyPublisher<[M.DomainModel], Error> {
        listenArray(mapper: mapper, range: nil) { $0 }
    }
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M, update: Realm.UpdatePolicy = .all) -> AnySinglePublisher<Void, Error> {
        save(object: object, mapper: mapper, update: update)
    }
    
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M, update: Realm.UpdatePolicy = .all) -> AnySinglePublisher<Void, Error> {
        save(objects: objects, mapper: mapper, update: update)
    }
    
    func count<T: ObjectToPersistenceMapper>(_ type: T.Type) -> AnySinglePublisher<Int, Error> {
        count(type) { $0 }
    }
}
