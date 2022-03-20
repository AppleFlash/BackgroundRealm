//
//  User.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Foundation
import RealmSwift

enum Role: String, CaseIterable, PersistableEnum {
	case director
	case employee
	case manager
}

struct User: Equatable, Identifiable {
    let id: UUID
	let role: Role
    let name: String
	var modifyCount: Int?
}

enum API {
	struct User: Equatable, Identifiable {
		let id: UUID
		let role: String
		let name: String
	}
}

enum Domain {
	struct User: Equatable, Identifiable {
		let id: UUID
		let role: Role
		var name: String
	}
}

class RealmUser: Object {
    @Persisted(primaryKey: true) var id: String = ""
	@Persisted var role: Role
	@Persisted var name: String = ""
	@Persisted var modifyCount: Int?
}

// MARK: - Mappers

struct UserMapper: ObjectToPersistenceMapper {
    func convert(model: User) -> RealmUser {
        let user = RealmUser()
        user.id = model.id.uuidString
		user.role = model.role
        user.name = model.name
		user.modifyCount = model.modifyCount
        return user
    }
}

struct RealmUserMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmUser) -> User {
        return User(
			id: UUID(uuidString: persistence.id) ?? UUID(),
			role: persistence.role,
			name: persistence.name,
			modifyCount: persistence.modifyCount
		)
    }
}
