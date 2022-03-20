//
//  UserStorage.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 01.06.2021.
//

import Foundation
import RealmSwift
import Combine

enum UserStorageError: Error {
	case containerNotExist
	case deleteNonExistingUser
	case updateNonExistingUser
}

final class UserStorage {
    private let gateway: PersistenceGateway
	private let containerId = "containerId"
	private let mapper = UserMapper()
    
    init() {
        let queue = DispatchQueue(label: "com.user.persistence")
		let config = Realm.Configuration(objectTypes: [RealmUser.self, AppRealmUserContainer.self])
		gateway = PersistenceGateway(regularScheduler: queue.eraseToAnyScheduler(), configuration: config)
    }
    
    func update(user: User) -> AnyPublisher<Void, Error> {
		return gateway.save(object: user, mapper: mapper.convert(model:), update: .modified)
    }
	
	func save(user: User) -> AnyPublisher<Void, Error> {
		return gateway.save(object: user, mapper: mapper.convert(model:), update: .all)
	}
	
	func saveToContainer(user: User) -> AnyPublisher<Void, Error> {
		let id = containerId
		return gateway.updateAction { realm in
			let objects = realm.objects(AppRealmUserContainer.self).filter("id = %@", id)
			guard let container = objects.first else {
				throw UserStorageError.containerNotExist
			}
			
			let realmUser = UserMapper().convert(model: user)
			container.usersList.append(realmUser)
		}
	}
	
	func saveToContainer(users: [User]) -> AnyPublisher<Void, Error> {
		let id = containerId
		return gateway.updateAction { realm in
			let objects = realm.objects(AppRealmUserContainer.self).filter("id = %@", id)
			guard let container = objects.first else {
				throw UserStorageError.containerNotExist
			}
			
			let mapper = UserMapper()
			let realmUsers = users.map(mapper.convert)
			container.usersList.append(objectsIn: realmUsers)
		}
	}
	
	func updateInContainer(user: User) -> AnyPublisher<Void, Error> {
		let id = containerId
		return gateway.updateAction { realm in
			let objects = realm.objects(AppRealmUserContainer.self).filter("id = %@", id)
			guard let container = objects.first else {
				throw UserStorageError.containerNotExist
			}
			
			guard let index = container.usersList.index(matching: "id = %@", user.id.uuidString) else {
				throw UserStorageError.updateNonExistingUser
			}
			
			let realmUser = realm.create(
				RealmUser.self,
				value: UserMapper().convert(model: user),
				update: .modified
			)
			container.usersList[index] = realmUser
		}
	}
	
	func deleteFromContainer(userAt userId: UUID) -> AnyPublisher<Void, Error> {
		let id = containerId
		return gateway.updateAction { realm in
			let objects = realm.objects(AppRealmUserContainer.self).filter("id = %@", id)
			guard let container = objects.first else {
				throw UserStorageError.containerNotExist
			}
			
			guard let index = container.usersList.index(matching: "id = %@", userId.uuidString) else {
				throw UserStorageError.deleteNonExistingUser
			}
			
			realm.delete(container.usersList[index])
		}
	}
	
	func listenChangesetContainer() -> AnyPublisher<PersistenceChangeset<User>, Error> {
		return gateway.listenOrderedArrayChanges(
			AppRealmUserContainer.self,
			mapper: RealmUserMapper().convert(persistence:),
			keyPath: \.usersList
		) { [containerId] in $0.filter("id = %@", containerId) }
	}
	
	func saveContainer() -> AnyPublisher<Void, Error> {
		let container = AppUserContainer(id: containerId, users: [])
		let mapper = AppDomainRealmUserContainerMapper(userMapper: UserMapper())
		return gateway.count(AppRealmUserContainer.self)
			.flatMap { [gateway] count -> AnyPublisher<Void, Error> in
				if count == 0 {
					return gateway.save(object: container, mapper: mapper.convert(model:), update: .all)
				} else {
					return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
				}
			}
			.eraseToAnyPublisher()
	}
    
    func getUser(id: String) -> AnyPublisher<User?, Error> {
		return gateway.get(mapper: RealmUserMapper().convert(persistence:)) { $0.filter("id = %@", id) }
    }
    
    func listenUser(id: String) -> AnyPublisher<User, Error> {
		return gateway.listen(mapper: RealmUserMapper().convert(persistence:)) { $0.filter("id = %@", id) }
    }
    
    func update(id: String) -> AnyPublisher<Void, Error> {
        return gateway.updateAction { realm in
            let user = realm.object(ofType: RealmUser.self, forPrimaryKey: id)!
            user.name = "update block name"
            
            let user2 = realm.object(ofType: RealmUser.self, forPrimaryKey: "ECF493DB-4EA2-4D93-9C7B-C9643634F576")!
            user2.name = "\(user2.name) updated"
        }
    }
    
    func delete(id: UUID) -> AnyPublisher<Void, Error> {
		return gateway.delete(RealmUser.self) { $0.filter("id = %@", id.uuidString) }
    }
}
