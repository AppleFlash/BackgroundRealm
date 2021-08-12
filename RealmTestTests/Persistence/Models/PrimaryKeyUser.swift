//
//  PrimaryKeyUser.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 12.06.2021.
//

@testable import RealmTest
import Foundation
import RealmSwift

struct PrimaryKeyUser: Equatable {
    let id: String
    var name: String
    let age: Int
}

final class RealmPrimaryKeyUser: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var name: String = ""
	@Persisted var age: Int = 0
}

// MARK: - Mappers

struct DomainRealmPrimaryMapper: ObjectToPersistenceMapper {
    func convert(model: PrimaryKeyUser) -> RealmPrimaryKeyUser {
        let user = RealmPrimaryKeyUser()
        user.id = model.id
        user.age = model.age
        user.name = model.name
        
        return user
    }
}

struct RealmDomainPrimaryMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmPrimaryKeyUser) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: persistence.id, name: persistence.name, age: persistence.age)
    }
}
