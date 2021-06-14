//
//  PersistencePrimaryGatewayTests.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 09.06.2021.
//

@testable import RealmTest
import XCTest
import RealmSwift
import Combine


// MARK: - Test

final class PersistencePrimaryGatewayTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence.primary")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory primary test realm")
        persistence = PersistenceGateway(queue: queue, configuration: config)
    }
    
    override func tearDown() {
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
    // MARK: Save
    
    func test_savePrimary_success() {
        // given
        let user = createUser()
        var saveError: Error?
        let expect = expectation(description: "save")

        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
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
    
    func test_updatePrimary_success() {
        // given
        let user = createUser()
        let newUserData = PrimaryKeyUser(id: user.id, name: "new name", age: -10)
        var updatedUser: PrimaryKeyUser?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.save(object: newUserData, mapper: DonainRealmPrimaryMapper())
            }
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainPrimaryMapper())
            }
            .sink { _ in } receiveValue: { user in
                updatedUser = user
                expect.fulfill()
            }
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(updatedUser, newUserData)
    }
    
    func test_updatePrimaryStillUnique_success() {
        // given
        let user = createUser()
        let newUserData = PrimaryKeyUser(id: user.id, name: "new name", age: -10)
        var count: Int?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.save(object: newUserData, mapper: DonainRealmPrimaryMapper())
            }
            .flatMap { [persistence] in
                persistence!.count(DonainRealmPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { objectsCount in
                count = objectsCount
                expect.fulfill()
            }
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(count, 1)
    }

    func test_savePrimaryArray_success() {
        // given
        let users = [createUser()]
        var saveError: Error?
        let expect = expectation(description: "save")

        // when
        persistence
            .save(objects: users, mapper: DonainRealmPrimaryMapper())
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

    func test_getPrimary_success() {
        // given
        let user = createUser()
        var savedUser: PrimaryKeyUser?
        let expect = expectation(description: "save")

        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainPrimaryMapper())
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

    func test_getPrimaryArray_success() {
        // given
        let users = [
            createUser(),
            createUser()
        ].sorted { $0.name < $1.name }
        var savedUsers: [PrimaryKeyUser] = []
        let expect = expectation(description: "save")

        // when
        persistence
            .save(objects: users, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.getArray(mapper: RealmDomainPrimaryMapper()) { results in
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
    
    // MARK: Delete
    
    func test_deletePrimary_success() {
        // given
        let users = [createUser(), createUser()]
        var countAfterDelete: Int?
        let expect = expectation(description: "save")
        
        // when
        persistence
            .save(objects: users, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.delete(DonainRealmPrimaryMapper.self) { $0.filter("id = %@", users.first!.id) }
            }
            .flatMap { [persistence] in
                persistence!.count(DonainRealmPrimaryMapper.self) { $0 }
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
    
    private func createUser(name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: "\(Int.random(in: 0...100))", name: name, age: age)
    }
}
