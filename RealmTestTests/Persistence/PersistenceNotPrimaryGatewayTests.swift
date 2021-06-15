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

// MARK: - Test

/// Тест кейсы по взаимодействию с объектами без primary key: сохранение, получение, удаление, количество
final class PersistenceNotPrimaryGatewayTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence.primary.not")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory not primary test realm")
        persistence = PersistenceGateway(scheduler: queue, configuration: config)
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
            .save(object: user, mapper: DonainRealmNotPrimaryMapper(), update: .all)
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
