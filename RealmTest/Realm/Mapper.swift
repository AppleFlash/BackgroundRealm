//
//  Mapper.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import RealmSwift

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
