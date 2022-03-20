//
//  Mapper.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import Foundation

protocol MapperProtocol {
	func mapApiToRealm(_ user: API.User) -> RealmUser
	func mapRealmToDomain(_ user: RealmUser) -> Domain.User
	func mapDomainToRealm(_ user: Domain.User) -> RealmUser
}

struct Mapper: MapperProtocol {
	func mapApiToRealm(_ user: API.User) -> RealmUser {
		let object = RealmUser()
		object.id = user.id.uuidString
		object.name = user.name
		object.role = Role(rawValue: user.role) ?? .employee
		
		return object
	}
	
	func mapRealmToDomain(_ user: RealmUser) -> Domain.User {
		return Domain.User(
			id: UUID(uuidString: user.id) ?? UUID(),
			role: user.role,
			name: user.name
		)
	}
	
	func mapDomainToRealm(_ user: Domain.User) -> RealmUser {
		let object = RealmUser()
		object.id = user.id.uuidString
		object.name = user.name
		object.role = user.role
		
		return object
	}
}
