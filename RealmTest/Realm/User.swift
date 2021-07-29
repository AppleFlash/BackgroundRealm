//
//  User.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Foundation
import RealmSwift

struct AppUserContainer: Equatable {
	let id: String
	let users: [User]
}

final class AppRealmUserContainer: Object {
	@objc dynamic var id: String = ""
	let usersList = List<RealmUser>()
	
	override class func primaryKey() -> String? {
		return #keyPath(id)
	}
}

struct AppDomainRealmUserContainerMapper: ObjectToPersistenceMapper {
	private let userMapper: UserMapper
	
	init(userMapper: UserMapper) {
		self.userMapper = userMapper
	}
	
	func convert(model: AppUserContainer) -> AppRealmUserContainer {
		let users = model.users.map(userMapper.convert)
		let container = AppRealmUserContainer()
		container.id = model.id
		container.usersList.append(objectsIn: users)
		
		return container
	}
}

struct AppRealmDomainUserContainerMapper: PersistenceToDomainMapper {
	private let userMapper: RealmUserMapper
	
	init(userMapper: RealmUserMapper) {
		self.userMapper = userMapper
	}
	
	func convert(persistence: AppRealmUserContainer) -> AppUserContainer {
		let users = persistence.usersList.map(userMapper.convert)
		return .init(id: persistence.id, users: Array(users))
	}
}

///

struct APIUser {
    let id: String
    let name: String
}

struct User: Equatable, Identifiable {
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
