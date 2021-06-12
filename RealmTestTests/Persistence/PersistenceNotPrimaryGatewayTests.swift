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

// MARK: - Objects

private struct NotPrimaryKeyUser: Equatable {
    let name: String
    let age: Int
}

final class RealmNotPrimaryKeyUser: Object {
    @objc dynamic var name: String = ""
    @objc dynamic var age: Int = 0
}

// MARK: - Mappers

private struct DonainRealmNotPrimaryMapper: ObjectToPersistenceMapper {
    func convert(model: NotPrimaryKeyUser) -> RealmNotPrimaryKeyUser {
        let user = RealmNotPrimaryKeyUser()
        user.age = model.age
        user.name = model.name
        
        return user
    }
}

private struct RealmDomainNotPrimaryMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmNotPrimaryKeyUser) -> NotPrimaryKeyUser {
        return NotPrimaryKeyUser(name: persistence.name, age: persistence.age)
    }
}

// MARK: - Test

final class PersistenceNotPrimaryGatewayTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory test realm")
        persistence = PersistenceGateway(queue: queue, configuration: config)
    }
    
    override func tearDown() {
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
    // MARK: Save
    
    func test_saveNotPrimary_success() {
        // given
        let user = createUser()
        var saveError: Error?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmNotPrimaryMapper())
            .sink { result in
                if case let .failure(error) = result {
                    saveError = error
                }
                expect.fulfill()
            } receiveValue: { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        XCTAssertNil(saveError)
    }
    
    func test_saveNotPrimaryArray_success() {
        // given
        let users = [createUser()]
        var saveError: Error?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(objects: users, mapper: DonainRealmNotPrimaryMapper())
            .sink { result in
                if case let .failure(error) = result {
                    saveError = error
                }
                expect.fulfill()
            } receiveValue: { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        XCTAssertNil(saveError)
    }
    
    // MARK: Get
    
    func test_getNotPrimary_success() {
        // given
        let user = createUser()
        var savedUser: NotPrimaryKeyUser?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainNotPrimaryMapper())
            }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { user in
                    savedUser = user
                    expect.fulfill()
                }
            )
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(user, savedUser)
    }
    
    func test_getNilNotPrimary_success() {
        // given
        var receivedUser: NotPrimaryKeyUser?
        let expect = expectation(description: "save")
        
        // when
        persistence.get(mapper: RealmDomainNotPrimaryMapper())
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { user in
                    receivedUser = user
                    expect.fulfill()
                }
            )
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        XCTAssertNil(receivedUser)
    }
    
    func test_updateNotPrimaryNotUnique_success() {
        // given
        let user = createUser()
        let newUserData = NotPrimaryKeyUser(name: "new name", age: -10)
        var count: Int?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.save(object: newUserData, mapper: DonainRealmNotPrimaryMapper())
            }
            .flatMap { [persistence] in
                persistence!.count(DonainRealmNotPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { objectsCount in
                count = objectsCount
                expect.fulfill()
            }
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(count, 2)
    }
    
    func test_getNotPrimaryArray_success() {
        // given
        let users = [createUser(), createUser()].sorted { $0.name < $1.name }
        var savedUsers: [NotPrimaryKeyUser] = []
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(objects: users, mapper: DonainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.getArray(mapper: RealmDomainNotPrimaryMapper()) { results in
                    results.filter("name IN %@", users.map(\.name))
                }
            }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { users in
                    savedUsers = users.sorted { $0.name < $1.name }
                    expect.fulfill()
                }
            )
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(users, savedUsers)
    }
    
    // MARK: Listen
    
    func test_listenSingleNotPrimaryObject_success() {
        // given
        let user = createUser()
        let expectedChangedAges = [20, 30]
        var changedAges: [Int] = []
        let expect = expectation(description: "save")
        persistence
            .listen(mapper: RealmDomainNotPrimaryMapper()) { results in
                results.filter("name = %@", user.name)
            }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { user in
                    changedAges.append(user.age)
                    if changedAges.count == expectedChangedAges.count {
                        expect.fulfill()
                    }
                }
            )
            .store(in: &subscriptions)

        // when
        persistence.save(object: NotPrimaryKeyUser(name: user.name, age: 20), mapper: DonainRealmNotPrimaryMapper())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: NotPrimaryKeyUser(name: user.name, age: 30), mapper: DonainRealmNotPrimaryMapper())
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(changedAges, expectedChangedAges)
    }
    
    func test_listenArrayOfNotPrimaryObject_validInsert_success() {
        // given
        let oldUser = createUser(age: 2)
        let newUser = createUser(age: 3)
        let users = [createUser(age: 1), createUser(age: 1), oldUser]
        let expectedUsers = [[oldUser], [oldUser, newUser]]
        var receivedUsers: [[NotPrimaryKeyUser]] = []
        let expect = expectation(description: "save")
        
        persistence!.listenArray(mapper: RealmDomainNotPrimaryMapper()) { $0.filter("age > %@", 1) }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { users in
                    if !users.isEmpty {
                        receivedUsers.append(users)
                    }
                    if receivedUsers.count == expectedUsers.count {
                        expect.fulfill()
                    }
                }
            )
            .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: DonainRealmNotPrimaryMapper())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: newUser, mapper: DonainRealmNotPrimaryMapper())
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    func test_listenArrayOfNotPrimaryObject_validDelete_success() {
        // given
        let users = [createUser(), createUser()]
        let expectedUsers = Array(users.dropLast())
        var receivedUsers: [NotPrimaryKeyUser] = []
        let expect = expectation(description: "save")
        
        persistence!.listenArray(mapper: RealmDomainNotPrimaryMapper()) { $0 }
            .dropFirst()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { users in
                    receivedUsers = users
                    expect.fulfill()
                }
            )
            .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: DonainRealmNotPrimaryMapper())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.delete(DonainRealmNotPrimaryMapper.self) { $0.filter("name = %@", users.last!.name) }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    // MARK: Delete
    
    func test_deleteNotPrimary_success() {
        // given
        let users = [createUser(), createUser()]
        var countAfterDelete: Int?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(objects: users, mapper: DonainRealmNotPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.delete(DonainRealmNotPrimaryMapper.self) { $0.filter("name = %@", users.first!.name) }
            }
            .flatMap { [persistence] in
                persistence!.count(DonainRealmNotPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { objectsCount in
                countAfterDelete = objectsCount
                expect.fulfill()
            }
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(countAfterDelete, 1)
    }
    
    private func createUser(name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> NotPrimaryKeyUser {
        return NotPrimaryKeyUser(name: name, age: age)
    }
}
