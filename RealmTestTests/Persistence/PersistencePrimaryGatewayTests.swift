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

/// Тест кейсы по взаимодействию с объектами с primary key: сохранение, обновление, получение, удаление
final class PersistencePrimaryGatewayTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let config = Realm.Configuration(inMemoryIdentifier: "in memory primary test realm \(UUID().uuidString)")
		persistence = PersistenceGateway(regularScheduler: .immediate, configuration: config)
    }
    
    override func tearDown() {
		persistence.deleteAll()
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
    // MARK: Save
    
    func test_savePrimary_success() {
        // given
        let user = createUser()
        var saveError: Error?

        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .sink { saveError = $0.error } receiveValue: { _ in }
            .store(in: &subscriptions)

        // then
        XCTAssertNil(saveError)
    }
    
    func test_updatePrimary_success() {
        // given
        let user = createUser()
        let newUserData = PrimaryKeyUser(id: user.id, name: "new name", age: -10)
        var updatedUser: PrimaryKeyUser?
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.save(object: newUserData, mapper: DonainRealmPrimaryMapper(), update: .modified)
            }
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainPrimaryMapper())
            }
            .sink { _ in } receiveValue: { updatedUser = $0 }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(updatedUser, newUserData)
    }
    
    func test_updatePrimaryStillUnique_success() {
        // given
        let user = createUser()
        let newUserData = PrimaryKeyUser(id: user.id, name: "new name", age: -10)
        var count: Int?
        
        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.save(object: newUserData, mapper: DonainRealmPrimaryMapper(), update: .modified)
            }
            .flatMap { [persistence] in
                persistence!.count(DonainRealmPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { count = $0 }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(count, 1)
    }

    func test_savePrimaryArray_success() {
        // given
        let users = [createUser()]
        var saveError: Error?

        // when
        persistence
            .save(objects: users, mapper: DonainRealmPrimaryMapper())
			.sink { saveError = $0.error } receiveValue: { _ in }
            .store(in: &subscriptions)

        // then
        XCTAssertNil(saveError)
    }

    // MARK: Get

    func test_getPrimary_success() {
        // given
        let user = createUser()
        var savedUser: PrimaryKeyUser?

        // when
        persistence
            .save(object: user, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainPrimaryMapper())
            }
            .sink { _ in } receiveValue: { savedUser = $0 }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(user, savedUser)
    }

    func test_getPrimaryArray_success() {
        // given
        let users = [
            createUser(),
            createUser()
        ].sorted { $0.name < $1.name }
        var savedUsers: [PrimaryKeyUser] = []

        // when
        persistence
            .save(objects: users, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.getArray(mapper: RealmDomainPrimaryMapper()) { results in
                    results.filter("name IN %@", users.map(\.name))
                }
            }
            .sink { _ in } receiveValue: { savedUsers = $0.sorted { $0.name < $1.name } }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(users, savedUsers)
    }
    
    // MARK: Delete
    
    func test_deletePrimary_success() {
        // given
        let users = [createUser(), createUser()]
        var countAfterDelete: Int?
        
        // when
        persistence
            .save(objects: users, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.delete(DonainRealmPrimaryMapper.self) { $0.filter("id = %@", users.first!.id) }
            }
            .flatMap { [persistence] in
                persistence!.count(DonainRealmPrimaryMapper.self) { $0 }
            }
            .sink { _ in } receiveValue: { countAfterDelete = $0 }
            .store(in: &subscriptions)

        // then
        XCTAssertEqual(countAfterDelete, 1)
    }
    
    private func createUser(name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: "\(Int.random(in: 0...100))", name: name, age: age)
    }
}
