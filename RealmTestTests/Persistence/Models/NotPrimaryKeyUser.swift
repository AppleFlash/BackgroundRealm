//
//  NotPrimaryKeyUser.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 12.06.2021.
//

@testable import RealmTest
import Foundation
import RealmSwift

struct NotPrimaryKeyUser: Equatable {
    let name: String
    let age: Int
}

final class RealmNotPrimaryKeyUser: Object {
	@Persisted var name: String = ""
	@Persisted var age: Int = 0
}

// MARK: - Mappers

struct DomainRealmNotPrimaryMapper: ObjectToPersistenceMapper {
    func convert(model: NotPrimaryKeyUser) -> RealmNotPrimaryKeyUser {
        let user = RealmNotPrimaryKeyUser()
        user.age = model.age
        user.name = model.name
        
        return user
    }
}

struct RealmDomainNotPrimaryMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmNotPrimaryKeyUser) -> NotPrimaryKeyUser {
        return NotPrimaryKeyUser(name: persistence.name, age: persistence.age)
    }
}
