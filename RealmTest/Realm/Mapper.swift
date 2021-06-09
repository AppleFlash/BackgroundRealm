//
//  Mapper.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import RealmSwift

//enum NonPersistenceObject<Domain, API> {
//    case domain(Domain)
//    case api(API)
//}

protocol PersistenceToDomainMapper {
    associatedtype DomainModel
    associatedtype PersistenceModel: Object
    func convert(persistence: PersistenceModel) -> DomainModel
}

protocol ObjectToPersistenceMapper {
    associatedtype Model
    associatedtype PersistenceModel: Object
    func convert(model: Model) -> PersistenceModel
}

//final class AnyMapper<T: Mapper>: Mapper {
//    private let convertDomainClosure: (T.DomainModel) -> T.PersistenceModel
//    private let convertPersistenceClosure: (T.PersistenceModel) -> T.DomainModel
//    
//    init(mapper: T) {
//        self.convertDomainClosure = mapper.convert(domain:)
//        self.convertPersistenceClosure = mapper.convert(persistence:)
//    }
//    
//    func convert(domain: T.DomainModel) -> T.PersistenceModel {
//        return convertDomainClosure(domain)
//    }
//    
//    func convert(persistence: T.PersistenceModel) -> T.DomainModel {
//        return convertPersistenceClosure(persistence)
//    }
//}
