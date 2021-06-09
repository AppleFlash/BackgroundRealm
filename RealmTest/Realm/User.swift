//
//  User.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Foundation
import RealmSwift

struct APIUser {
    let id: String
    let name: String
}

struct User {
    let id: UUID
    var name: String
}

class RealmUser: Object {
    @objc dynamic var id: String = ""
    @objc dynamic var name: String = ""
    
    override class func primaryKey() -> String? {
        return #keyPath(id)
    }
}

// MARK: - Mapper

struct UserMapper: ObjectToPersistenceMapper {
    func convert(model: User) -> RealmUser {
        let user = RealmUser()
        user.id = model.id.uuidString
        user.name = model.name
        return user
    }
}

struct APIUserMapper: ObjectToPersistenceMapper {
    func convert(model: APIUser) -> RealmUser {
        let user = RealmUser()
        user.id = model.id
        user.name = model.name
        return user
    }
}

struct RealmUserMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmUser) -> User {
        return User(id: UUID(uuidString: persistence.id) ?? UUID(), name: persistence.name)
    }
}
