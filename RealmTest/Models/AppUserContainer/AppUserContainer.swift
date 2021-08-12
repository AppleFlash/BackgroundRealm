//
//  AppUserContainer.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

import RealmSwift

struct AppUserContainer: Equatable {
	let id: String
	let users: [User]
}

final class AppRealmUserContainer: Object {
	@Persisted(primaryKey: true) var id: String = ""
	@Persisted var usersList = List<RealmUser>()
}

// MARK: - Mappers

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
