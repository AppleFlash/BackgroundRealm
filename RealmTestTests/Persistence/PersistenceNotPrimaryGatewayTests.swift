//
//  PersistenceGatewayTests.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 09.06.2021.
//

@testable import RealmTest
import XCTest
import RealmSwift
import Combine

extension Subscribers.Completion {
	var error: Failure? {
		switch self {
		case let .failure(error):
			return error
		default:
			return nil
		}
	}
}

// MARK: - Test

/// Тест кейсы по взаимодействию с объектами без primary key: сохранение, получение, удаление, количество
final class PersistenceNotPrimaryGatewayTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
	
    override func setUp() {
        super.setUp()
        
		let config = Realm.Configuration(inMemoryIdentifier: "in memory not primary test realm \(UUID().uuidString)")
		persistence = PersistenceGateway(regularScheduler: .immediate, configuration: config)
    }
    
    override func tearDown() {
		persistence.deleteAll()
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
    // MARK: Save
    
    func test_saveNotPrimary_success() {
        // given
        let user = createUser()
        var saveError: Error?
        
        // when
        persistence
            .save(object: user, mapper: DomainRealmNotPrimaryMapper())
			.sink { saveError = $0.error } receiveValue: { _ in }
            .store(in: &subscriptions)
        
        // then
        XCTAssertNil(saveError)
    }
    
    func test_saveNotPrimaryArray_success() {
        // given
        let users = [createUser()]
        var saveError: Error?
        
        // when
        persistence
            .save(objects: users, mapper: DomainRealmNotPrimaryMapper())
            .sink { saveError = $0.error } receiveValue: { _ in }
            .store(in: &subscriptions)
        
        // then
        XCTAssertNil(saveError)
    }
    
    // MARK: Get
    
    func test_getNotPrimary_success() {
        // given
        let user = createUser()
        var savedUser: NotPrimaryKeyUser?
        
        // when
        persistence
            .save(object: user, mapper: DomainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainNotPrimaryMapper())
            }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { savedUser = $0 }
            )
            .store(in: &subscriptions)
        
        // then
        XCTAssertEqual(user, savedUser)
    }
    
    func test_getNilNotPrimary_success() {
        // given
        var receivedUser: NotPrimaryKeyUser?
        
        // when
        persistence.get(mapper: RealmDomainNotPrimaryMapper())
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { receivedUser = $0 }
            )
            .store(in: &subscriptions)
        
        // then
        XCTAssertNil(receivedUser)
    }
    
    func test_updateNotPrimaryNotUnique_success() {
        // given
        let user = createUser()
        let newUserData = NotPrimaryKeyUser(name: "new name", age: -10)
        var count: Int?
        
        // when
        persistence
            .save(object: user, mapper: DomainRealmNotPrimaryMapper(), update: .all)
            .flatMap { [persistence] in
                persistence!.save(object: newUserData, mapper: DomainRealmNotPrimaryMapper())
            }
            .flatMap { [persistence] in
                persistence!.count(DomainRealmNotPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { count = $0 }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(count, 2)
    }
    
    func test_getNotPrimaryArray_success() {
        // given
        let users = [createUser(), createUser()].sorted { $0.name < $1.name }
        var savedUsers: [NotPrimaryKeyUser] = []
        
        // when
        persistence
            .save(objects: users, mapper: DomainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.getArray(mapper: RealmDomainNotPrimaryMapper()) { results in
                    results.filter("name IN %@", users.map(\.name))
                }
            }
            .sink { _ in } receiveValue: { savedUsers = $0.sorted { $0.name < $1.name } }
            
            .store(in: &subscriptions)
        
        // then
        XCTAssertEqual(users, savedUsers)
    }
        
    // MARK: Delete
    
    func test_deleteNotPrimary_success() {
        // given
        let users = [createUser(), createUser()]
        var countAfterDelete: Int?
        
        // when
        persistence
            .save(objects: users, mapper: DomainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.delete(DomainRealmNotPrimaryMapper.self) { $0.filter("name = %@", users.first!.name) }
            }
            .flatMap { [persistence] in
                persistence!.count(DomainRealmNotPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { countAfterDelete = $0 }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(countAfterDelete, 1)
    }
    
    func test_saveContainer() {
        // given
        let users: [PrimaryKeyUser] = [.init(id: "1", name: "1", age: 1), .init(id: "2", name: "2", age: 2), .init(id: "3", name: "3", age: 3)]
        let toSave = UserContainer(users: users)
		var didSave = false
        
        // when
        let userMapper = DomainRealmPrimaryMapper()
        let mapper = DomainRealmUsersContainerMapper(userMapper: userMapper)
        persistence.save(object: toSave, mapper: mapper, update: .all)
			.sink(receiveCompletion: { _ in }, receiveValue: { didSave = true })
            .store(in: &subscriptions)
        
        // then
        XCTAssertTrue(didSave)
    }
    
    func test_getContainer() {
        // given
        let users: [PrimaryKeyUser] = [.init(id: "1", name: "1", age: 1), .init(id: "2", name: "2", age: 2), .init(id: "3", name: "3", age: 3)]
        let toSave = UserContainer(users: users)
        var received: UserContainer?
        
        // when
        let getMapper = RealmDomainUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersContainerMapper(userMapper: .init())
        persistence.save(object: toSave, mapper: saveMapper, update: .all)
            .flatMap { [persistence] in
                persistence!.get(mapper: getMapper)
            }
            .sink { _ in } receiveValue: { received = $0 }
            .store(in: &subscriptions)
        
        // then
        XCTAssertEqual(toSave, received)
    }
    
    func test_deleteObjectFromContainer() {
        // given
        let usersToSave: [PrimaryKeyUser] = [.init(id: "1", name: "1", age: 1), .init(id: "2", name: "2", age: 2), .init(id: "3", name: "3", age: 3)]
        let toSave = UserContainer(users: usersToSave)
        let resultsUsers = usersToSave.dropLast()
        let resultsContainer = UserContainer(users: Array(resultsUsers))
        var received: UserContainer?
        
        // when
        let getMapper = RealmDomainUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersContainerMapper(userMapper: .init())
        persistence.save(object: toSave, mapper: saveMapper, update: .all)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    let list = realm.objects(RealmUserContainer.self).first!
                    let index = list.usersList.index(matching: NSPredicate(format: "id = %@", usersToSave.last!.id))!
                    list.usersList.remove(at: index)
                }
            }
            .flatMap { [persistence] in
                persistence!.get(mapper: getMapper)
            }
            .sink { _ in } receiveValue: { received = $0 }
            .store(in: &subscriptions)
        
        // then
        XCTAssertEqual(resultsContainer, received)
    }
    
    private func createUser(name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> NotPrimaryKeyUser {
        return NotPrimaryKeyUser(name: name, age: age)
    }
}
