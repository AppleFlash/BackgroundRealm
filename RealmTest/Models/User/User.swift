//
//  User.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Foundation
import RealmSwift

struct User: Equatable, Identifiable {
    let id: UUID
    var name: String
}

class RealmUser: Object {
    @Persisted(primaryKey: true) var id: String = ""
	@Persisted var name: String = ""
}

// MARK: - Mappers

struct UserMapper: ObjectToPersistenceMapper {
    func convert(model: User) -> RealmUser {
        let user = RealmUser()
        user.id = model.id.uuidString
        user.name = model.name
        return user
    }
}

struct RealmUserMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmUser) -> User {
        return User(id: UUID(uuidString: persistence.id) ?? UUID(), name: persistence.name)
    }
}
