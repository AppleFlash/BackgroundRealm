//
//  KeyedUserContainer.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

@testable import RealmTest
import RealmSwift

struct KeyedUserContainer: Equatable {
	let id: String
	let users: [PrimaryKeyUser]
}

final class RealmKeyedUserContainer: Object {
	@Persisted(primaryKey: true) var id: String = ""
	@Persisted var usersList = List<RealmPrimaryKeyUser>()
}

// MARK: - Mappers

struct DomainRealmUsersKeyedContainerMapper: ObjectToPersistenceMapper {
	private let userMapper: DomainRealmPrimaryMapper
	
	init(userMapper: DomainRealmPrimaryMapper) {
		self.userMapper = userMapper
	}
	
	func convert(model: KeyedUserContainer) -> RealmKeyedUserContainer {
		let users = model.users.map(userMapper.convert)
		let container = RealmKeyedUserContainer()
		container.id = model.id
		container.usersList.append(objectsIn: users)
		
		return container
	}
}

struct RealmDomainKeyedUserContainerMapper: PersistenceToDomainMapper {
	private let userMapper: RealmDomainPrimaryMapper
	
	init(userMapper: RealmDomainPrimaryMapper) {
		self.userMapper = userMapper
	}
	
	func convert(persistence: RealmKeyedUserContainer) -> KeyedUserContainer {
		let users = persistence.usersList.map(userMapper.convert)
		return .init(id: persistence.id, users: Array(users))
	}
}
