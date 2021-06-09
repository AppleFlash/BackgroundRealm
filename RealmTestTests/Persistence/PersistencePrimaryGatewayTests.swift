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

// MARK: - Objects


private struct PrimaryKeyUser: Equatable {
    let id: String
    let name: String
    let age: Int
}

final class RealmPrimaryKeyUser: Object {
    @objc dynamic var id: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var age: Int = 0
    
    override class func primaryKey() -> String? {
        return #keyPath(id)
    }
}

// MARK: - Mappers

private struct DonainRealmPrimaryMapper: ObjectToPersistenceMapper {
    func convert(model: PrimaryKeyUser) -> RealmPrimaryKeyUser {
        let user = RealmPrimaryKeyUser()
        user.id = model.id
        user.age = model.age
        user.name = model.name
        
        return user
    }
}

private struct RealmDomainPrimaryMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmPrimaryKeyUser) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: persistence.id, name: persistence.name, age: persistence.age)
    }
}

// MARK: - Test

final class PersistencePrimaryGatewayTests: XCTestCase {
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
                persistence!.count(type: DonainRealmPrimaryMapper.self) { $0 }
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
    
    // MARK: Listen
    
    func test_listenSinglePrimaryObject_success() {
        // given
        let user = PrimaryKeyUser(id: "id1", name: UUID().uuidString, age: .random(in: 10...99))
        let expectedChangedAges = [20, 30]
        var changedAges: [Int] = []
        let expect = expectation(description: "save")
        persistence
            .listen(mapper: RealmDomainPrimaryMapper()) { results in
                results.filter("id = %@", user.id)
            }
            .print()
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
        persistence.save(object: PrimaryKeyUser(id: user.id, name: user.name, age: 20), mapper: DonainRealmPrimaryMapper())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: PrimaryKeyUser(id: user.id, name: user.name, age: 30), mapper: DonainRealmPrimaryMapper())
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(changedAges, expectedChangedAges)
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
                persistence!.count(type: DonainRealmPrimaryMapper.self) { $0 }
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
    
    private func createUser() -> PrimaryKeyUser {
        return PrimaryKeyUser(id: "\(Int.random(in: 0...100))", name: UUID().uuidString, age: .random(in: 10...80))
    }
}
