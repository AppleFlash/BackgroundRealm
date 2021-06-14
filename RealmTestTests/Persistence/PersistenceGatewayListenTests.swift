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

final class PersistenceGatewayListenTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory listen test realm")
        persistence = PersistenceGateway(queue: queue, configuration: config)
    }
    
    override func tearDown() {
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
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
    
    func test_listenArrayOfPrimaryObject_validInsert_success() {
        // given
        let oldUser = createUser(age: 2)
        let newUser = createUser(age: 3)
        let users = [createUser(age: 1), createUser(age: 1), oldUser]
        let expectedUsers = [[oldUser], [oldUser, newUser]]
        var receivedUsers: [[PrimaryKeyUser]] = []
        let expect = expectation(description: "save")
        
        persistence.listenArray(mapper: RealmDomainPrimaryMapper(), range: nil) {
            $0.filter("age > %@", 1).sorted(byKeyPath: #keyPath(RealmPrimaryKeyUser.age), ascending: true)
        }
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
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: newUser, mapper: DonainRealmPrimaryMapper())
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    func test_listenArrayOfPrimaryObject_validDelete_success() {
        // given
        let users = [createUser(), createUser()]
        let expectedUsers = Array(users.dropLast())
        var receivedUsers: [PrimaryKeyUser] = []
        let expect = expectation(description: "save")
        persistence!.listenArray(mapper: RealmDomainPrimaryMapper())
            .dropFirst(2)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { users in
                    receivedUsers = users
                    expect.fulfill()
                }
            )
            .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.delete(DonainRealmPrimaryMapper.self) { $0.filter("id = %@", users.last!.id) }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
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
        let expect = expectation(description: "save")
        
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
            .flatMap { [persistence] in
                persistence!.listenArray(mapper: RealmDomainPrimaryMapper())
            }
            .dropFirst()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { users in
                    receivedUsers = users.sorted { $0.name < $1.name }
                    expect.fulfill()
                }
            )
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: updatedUser, mapper: DonainRealmPrimaryMapper())
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    func test_listenArrayOfRangePrimaryObject_success() {
        // given
        let users = (0..<20).map { createUser(age: $0) }
        let expectedUsers = Array(users.filter { $0.age > 10 }.prefix(5))
        var receivedUsers: [PrimaryKeyUser] = []
        let expect = expectation(description: "save")

        persistence.listenArray(mapper: RealmDomainPrimaryMapper(), range: 0..<5) {
            $0.filter("age > 10").sorted(byKeyPath: #keyPath(RealmPrimaryKeyUser.age), ascending: true)
        }
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
        persistence.save(objects: users, mapper: DonainRealmPrimaryMapper())
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &subscriptions)

        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    // MARK: Changeset
    
    func test_listenChangeset_initial_success() {
        // given
        let users = (0..<3).map { createUser(id: "\($0)") }
        var changeset: PersistenceChangeset<PrimaryKeyUser, Error>?
        let expect = expectation(description: "listen")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        // when
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                changeset = receivedChangeset
                expect.fulfill()
            }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        switch changeset {
        case let .initial(objects):
            let receivedUsers =  objects.sorted { $0.id < $1.id }
            XCTAssertEqual(receivedUsers, users)
        default:
            XCTFail()
        }
    }
    
    func test_listenChangeset_update_success() {
        // given
        let firstDeleteUser = createUser(age: 0)
        let userToModify = createUser(age: 1)
        let middleDeleteUser = createUser(age: 2)
        let simpleUser = createUser(age: 3)
        let lastDeleteUser = createUser(age: 4)
        let userToInsert = createUser(age: 5)
        
        let users = [firstDeleteUser, userToModify, middleDeleteUser, simpleUser, lastDeleteUser]
        let expect = expectation(description: "listen")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        var modifiedUser = userToModify
        modifiedUser.name = "modified"
        let expectedUsersList = [modifiedUser, simpleUser, userToInsert]
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0.sorted(byKeyPath: #keyPath(RealmPrimaryKeyUser.age), ascending: true) }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                switch receivedChangeset {
                case let .initial(objects):
                    resultUsersList = objects
                case let .update(deleted, inserted, modified):
                    deleted.reversed().forEach { resultUsersList.remove(at: $0) }
                    inserted.forEach { resultUsersList.insert($0.item, at: $0.index) }
                    modified.forEach { resultUsersList[$0.index] = $0.item }
                    
                case .error:
                    break
                }
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: domainMapper)
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    realm.add(domainMapper.convert(model: userToInsert), update: .all)
                    realm.add(domainMapper.convert(model: modifiedUser), update: .modified)
                    let deleteIds = [firstDeleteUser, middleDeleteUser, lastDeleteUser].map(\.id)
                    realm.delete(realm.objects(RealmPrimaryKeyUser.self).filter("id IN %@", deleteIds))
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 2)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    private func createUser(id: String = "\(UUID().hashValue)",  name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: id, name: name, age: age)
    }
}
