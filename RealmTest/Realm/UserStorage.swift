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
    private let gateway: PersistenceGateway<DispatchQueue>
	private let containerId = "containerId"
    
    init() {
        let queue = DispatchQueue(label: "com.user.persistence")
		let config = Realm.Configuration(objectTypes: [RealmUser.self, AppRealmUserContainer.self])
        gateway = PersistenceGateway(scheduler: queue, configuration: config)
    }
    
    func update(user: User) -> AnySinglePublisher<Void, Error> {
        return gateway.save(object: user, mapper: UserMapper(), update: .modified)
    }
    
    func save(user: APIUser) -> AnySinglePublisher<Void, Error> {
        return gateway.save(object: user, mapper: APIUserMapper(), update: .all)
    }
	
	func save(user: User) -> AnySinglePublisher<Void, Error> {
		return gateway.save(object: user, mapper: UserMapper(), update: .all)
	}
	
	func saveToContainer(user: User) -> AnySinglePublisher<Void, Error> {
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
	
	func saveToContainer(users: [User]) -> AnySinglePublisher<Void, Error> {
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
	
	func updateInContainer(user: User) -> AnySinglePublisher<Void, Error> {
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
	
	func deleteFromContainer(userAt userId: UUID) -> AnySinglePublisher<Void, Error> {
		let id = containerId
		return gateway.updateAction { realm in
			let objects = realm.objects(AppRealmUserContainer.self).filter("id = %@", id)
			guard let container = objects.first else {
				throw UserStorageError.containerNotExist
			}
			
			guard let index = container.usersList.index(matching: "id = %@", userId.uuidString) else {
				throw UserStorageError.deleteNonExistingUser
			}
			
			container.usersList.remove(at: index)
		}
	}
	
	func listenChangesetContainer() -> AnyPublisher<PersistenceChangeset<User>, Error> {
		return gateway.listenOrderedArrayChanges(
			AppRealmDomainUserContainerMapper.self,
			mapper: RealmUserMapper()
		) { [containerId] in $0.filter("id = %@", containerId).first?.usersList }
	}
	
	func saveContainer() -> AnySinglePublisher<Void, Error> {
		let container = AppUserContainer(id: containerId, users: [])
		let mapper = AppDomainRealmUserContainerMapper(userMapper: UserMapper())
		return gateway.count(AppDomainRealmUserContainerMapper.self)
			.flatMap { [gateway] count -> AnySinglePublisher<Void, Error> in
				if count == 0 {
					return gateway.save(object: container, mapper: mapper, update: .all)
				} else {
					return Just(()).setFailureType(to: Error.self).eraseToAnySinglePublisher()
				}
			}
			.eraseToAnySinglePublisher()
	}
    
    func getUser(id: String) -> AnySinglePublisher<User?, Error> {
        return gateway.get(mapper: RealmUserMapper()) { $0.filter("id = %@", id) }
    }
    
    func listenUser(id: String) -> AnyPublisher<User, Error> {
        return gateway.listen(mapper: RealmUserMapper()) { $0.filter("id = %@", id) }
    }
    
    func update(id: String) -> AnySinglePublisher<Void, Error> {
        return gateway.updateAction { realm in
            let user = realm.object(ofType: RealmUser.self, forPrimaryKey: id)!
            user.name = "update block name"
            
            let user2 = realm.object(ofType: RealmUser.self, forPrimaryKey: "ECF493DB-4EA2-4D93-9C7B-C9643634F576")!
            user2.name = "\(user2.name) updated"
        }
    }
    
    func delete(id: UUID) -> AnySinglePublisher<Void, Error> {
		return gateway.delete(UserMapper.self) { $0.filter("id = %@", id.uuidString) }
    }
    
    func getWithClosure(id: String, completion: @escaping (Result<User, Error>) -> Void) {
//        closureGateway.get(mapper: RealmUserMapper(), filterBlock: { $0.filter("id = %@", id) }, completion: completion)
    }
    
//    func delete(user: User) -> AnyPublisher<Void, Error> {
//        return gateway.delete(object: user, mapper: UserMapper())
//    }
}
