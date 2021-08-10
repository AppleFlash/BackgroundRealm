//
//  PersistenceGatewayListenTests.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 12.06.2021.
//

@testable import RealmTest
import XCTest
import RealmSwift
import Combine

/// Тест кейсы по наблюдению за объектами. Наблюдение как за одним объектом так и за массивом. В случае с наблюдением за массивом - всегда возвращается массив, не диф
final class PersistenceGatewayListenTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
	private var listenScheduler: TestSchedulerOf<RunLoop>!
    
    override func setUp() {
        super.setUp()
        
		listenScheduler = RunLoop.test
        let config = Realm.Configuration(inMemoryIdentifier: "in memory listen test realm \(UUID().uuidString)")
		persistence = PersistenceGateway(regularScheduler: .immediate, listenScheduler: listenScheduler.eraseToAnyScheduler(), configuration: config)
    }
    
    override func tearDown() {
		persistence.deleteAll()
        persistence = nil
        subscriptions.removeAll()
		listenScheduler = nil
        
        super.tearDown()
    }
    
    // MARK: Listen
    
    func test_listenSinglePrimaryObject_success() {
        // given
        let user = PrimaryKeyUser(id: "id1", name: UUID().uuidString, age: .random(in: 10...99))
        let expectedChangedAges = [20, 30]
        var changedAges: [Int] = []
        persistence
            .listen(mapper: RealmDomainPrimaryMapper()) { results in
                results.filter("id = %@", user.id)
            }
            .sink { _ in } receiveValue: { changedAges.append($0.age) }
            .store(in: &subscriptions)

        // when
        persistence.save(object: PrimaryKeyUser(id: user.id, name: user.name, age: 20), mapper: DonainRealmPrimaryMapper())
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
            .flatMap {
				self.persistence.save(object: PrimaryKeyUser(id: user.id, name: user.name, age: 30), mapper: DonainRealmPrimaryMapper())
            }
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
			.sink()
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(changedAges, expectedChangedAges)
    }
    
    func test_listenArrayOfPrimaryObject_validInsert_success() {
        // given
        let oldUser = createUser(age: 2)
        let newUser = createUser(age: 3)
        let users = [createUser(age: 1), createUser(age: 1), oldUser]
        let expectedUsers = [[oldUser], [oldUser, newUser]]
        var receivedUsers: [[PrimaryKeyUser]] = []
        
        persistence.listenArray(mapper: RealmDomainPrimaryMapper(), range: nil) {
            $0.filter("age > %@", 1).sorted(byKeyPath: #keyPath(RealmPrimaryKeyUser.age), ascending: true)
        }
		.filter { !$0.isEmpty }
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { receivedUsers.append($0) }
        )
        .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
            .flatMap {
				self.persistence.save(object: newUser, mapper: DonainRealmPrimaryMapper())
            }
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
			.sink()
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    func test_listenArrayOfPrimaryObject_validDelete_success() {
        // given
        let users = [createUser(), createUser()]
        let expectedUsers = Array(users.dropLast())
        var receivedUsers: [PrimaryKeyUser] = []
		
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
			.flatMap {
				self.persistence.listenArray(mapper: RealmDomainPrimaryMapper())
			}
			.sink { _ in } receiveValue: { receivedUsers = $0 }
			.store(in: &subscriptions)
        
        // when
		persistence.delete(DonainRealmPrimaryMapper.self) { $0.filter("id = %@", users.last!.id) }
			.sink()
			.store(in: &subscriptions)
		
		listenScheduler.run()

        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    func test_listenArrayOfPrimaryObject_validUpdate_success() {
        // given
        let firstUser = createUser()
        let secondUser = createUser(name: "zzz")
        var updatedUser = firstUser
        updatedUser.name = "updated user"
        let users = [firstUser, secondUser].sorted { $0.name < $1.name }
        let expectedUsers = [updatedUser, secondUser]
        var receivedUsers: [PrimaryKeyUser] = []
        
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
            .flatMap {
				self.persistence.listenArray(mapper: RealmDomainPrimaryMapper())
            }
            .sink { _ in } receiveValue: { receivedUsers = $0.sorted { $0.name < $1.name } }
            .store(in: &subscriptions)
        
        // when
		persistence.save(object: updatedUser, mapper: DonainRealmPrimaryMapper())
            .sink()
            .store(in: &subscriptions)
		
		listenScheduler.run()

        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    func test_listenArrayOfRangePrimaryObject_success() {
        // given
        let users = (0..<20).map { createUser(age: $0) }
        let expectedUsers = Array(users.filter { $0.age > 10 }.prefix(5))
        var receivedUsers: [PrimaryKeyUser] = []

        persistence.listenArray(mapper: RealmDomainPrimaryMapper(), range: 0..<5) {
            $0.filter("age > 10").sorted(byKeyPath: #keyPath(RealmPrimaryKeyUser.age), ascending: true)
        }
        .sink { _ in } receiveValue: { receivedUsers = $0 }
        .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
			.sink()
            .store(in: &subscriptions)
		
		listenScheduler.run()

        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    // MARK: Listen container after create
    
    func test_listenContainer_containerExistsBeforeStartListen() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        var count = 0
        var received: KeyedUserContainer?
        
        // when
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
        persistence.save(object: container, mapper: saveMapper, update: .all)
            .flatMap {
				self.persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
		
		listenScheduler.run()
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(container, received)
    }
    
    func test_listenContainer_containerExistsBeforeStartListen_addNew() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        let newUser = createUser(id: "3", name: "3")
        let updatedUsers = users + [newUser]
        let resultContainer = KeyedUserContainer(id: "1", users: updatedUsers)
        var count = 0
        var received: KeyedUserContainer?
        
        // when
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
		let saveSubject = persistence.save(object: container, mapper: saveMapper, update: .all)
        saveSubject
            .flatMap {
				self.persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            }
			.dropFirst()
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
		saveSubject
			.flatMap {
				self.persistence.updateAction { realm in
					let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
					list.usersList.append(DonainRealmPrimaryMapper().convert(model: newUser))
				}
			}
			.sink()
			.store(in: &self.subscriptions)
		
		listenScheduler.advance()
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(resultContainer, received)
    }
    
    func test_listenContainer_containerExistsBeforeStartListen_modify() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        var modifiedUsers = users
        modifiedUsers[0].name = "updated \(modifiedUsers[0].name)"
        let resultContainer = KeyedUserContainer(id: "1", users: modifiedUsers)
        var count = 0
        var received: KeyedUserContainer?
        
        // when
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
		let saveSubject = persistence.save(object: container, mapper: saveMapper, update: .all)
        saveSubject
            .flatMap {
				self.persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            }
			.dropFirst()
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
		saveSubject
			.flatMap {
				self.persistence.updateAction { realm in
					let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
					let index = list.usersList.index(matching: NSPredicate(format: "id = %@", users[0].id))!
					let realmUser = DonainRealmPrimaryMapper().convert(model: modifiedUsers[0])
					let obj = realm.create(RealmPrimaryKeyUser.self, value: realmUser, update: .all)
					list.usersList[index] = obj
				}
			}
			.sink()
			.store(in: &self.subscriptions)
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(resultContainer, received)
    }
    
    func test_listenContainer_containerExistsBeforeStartListen_delete() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        let updatedUsers = Array(users.dropLast())
        let resultContainer = KeyedUserContainer(id: "1", users: updatedUsers)
        var count = 0
        var received: KeyedUserContainer?
        
        // when
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
		let saveSubject = persistence.save(object: container, mapper: saveMapper, update: .all)
		
        saveSubject
            .flatMap {
				self.persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            }
			.dropFirst()
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
		saveSubject
			.flatMap {
				self.persistence.updateAction { realm in
					let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
					let index = list.usersList.index(matching: NSPredicate(format: "id = %@", users[1].id))!
					list.usersList.remove(at: index)
				}
			}
			.sink()
			.store(in: &self.subscriptions)
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(resultContainer, received)
    }
    
    // MARK: Listen container before create
    
    func test_listenContainer_containerNotExistsBeforeStartListen() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        var count = 0
        var received: KeyedUserContainer?
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
        
        persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
        
        // when
        persistence.save(object: container, mapper: saveMapper, update: .all)
            .sink()
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(container, received)
    }
    
    func test_listenContainer_containerNotExistsBeforeStartListen_addNew() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        let newUser = createUser(id: "3", name: "3")
        let updatedUsers = users + [newUser]
        let resultContainer = KeyedUserContainer(id: "1", users: updatedUsers)
        var count = 0
        var received: KeyedUserContainer?
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
        
        persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
        
        // when
        persistence.save(object: container, mapper: saveMapper, update: .all)
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
            .flatMap {
				self.persistence.updateAction { realm in
                    let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
                    list.usersList.append(DonainRealmPrimaryMapper().convert(model: newUser))
                }
            }
            .sink()
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(resultContainer, received)
    }
    
    func test_listenContainer_containerNotExistsBeforeStartListen_modify() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        var modifiedUsers = users
        modifiedUsers[0].name = "updated \(modifiedUsers[0].name)"
        let resultContainer = KeyedUserContainer(id: "1", users: modifiedUsers)
        var count = 0
        var received: KeyedUserContainer?
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
        
        persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
        
        // when
        
        persistence.save(object: container, mapper: saveMapper, update: .all)
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
            .flatMap {
				self.persistence.updateAction { realm in
                    let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
                    let index = list.usersList.index(matching: NSPredicate(format: "id = %@", users[0].id))!
                    let realmUser = DonainRealmPrimaryMapper().convert(model: modifiedUsers[0])
                    let obj = realm.create(RealmPrimaryKeyUser.self, value: realmUser, update: .all)
                    list.usersList[index] = obj
                }
            }
            .sink()
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(resultContainer, received)
    }
    
    func test_listenContainer_containerNotExistsBeforeStartListen_delete() {
        // given
        let users: [PrimaryKeyUser] = [createUser(id: "1", name: "1"), createUser(id: "2", name: "2")]
        let container = KeyedUserContainer(id: "1", users: users)
        let updatedUsers = Array(users.dropLast())
        let resultContainer = KeyedUserContainer(id: "1", users: updatedUsers)
        var count = 0
        var received: KeyedUserContainer?
        let getMapper = RealmDomainKeyedUserContainerMapper(userMapper: .init())
        let saveMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
        
        persistence.listen(mapper: getMapper) { $0.filter("id = %@", container.id) }
            .sink(receiveCompletion: { _ in }, receiveValue: {
                count += 1
                received = $0
            })
            .store(in: &subscriptions)
        
        // when
        persistence.save(object: container, mapper: saveMapper, update: .all)
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
            .flatMap {
				self.persistence.updateAction { realm in
                    let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
                    let index = list.usersList.index(matching: NSPredicate(format: "id = %@", users[1].id))!
                    list.usersList.remove(at: index)
                }
            }
            .sink()
            .store(in: &subscriptions)
		
		listenScheduler.advance()
        
        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(resultContainer, received)
    }
        
    private func createUser(id: String = "\(UUID().hashValue)",  name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: id, name: name, age: age)
    }
}
