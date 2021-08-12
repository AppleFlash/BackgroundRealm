//
//  UserContainer.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

@testable import RealmTest
import RealmSwift

struct UserContainer: Equatable {
	let users: [PrimaryKeyUser]
}

final class RealmUserContainer: Object {
	@Persisted var usersList = List<RealmPrimaryKeyUser>()
}

// MARK: - Mappers

struct DomainRealmUsersContainerMapper: ObjectToPersistenceMapper {
	private let userMapper: DomainRealmPrimaryMapper
	
	init(userMapper: DomainRealmPrimaryMapper) {
		self.userMapper = userMapper
	}
	
	func convert(model: UserContainer) -> RealmUserContainer {
		let users = model.users.map(userMapper.convert)
		let container = RealmUserContainer()
		container.usersList.append(objectsIn: users)
		
		return container
	}
}

struct RealmDomainUserContainerMapper: PersistenceToDomainMapper {
	private let userMapper: RealmDomainPrimaryMapper
	
	init(userMapper: RealmDomainPrimaryMapper) {
		self.userMapper = userMapper
	}
	
	func convert(persistence: RealmUserContainer) -> UserContainer {
		let users = persistence.usersList.map(userMapper.convert)
		return .init(users: Array(users))
	}
}
