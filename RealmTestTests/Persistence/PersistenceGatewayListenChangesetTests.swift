//
//  PersistenceGatewayListenChangesetTests.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 14.06.2021.
//

@testable import RealmTest
import XCTest
import RealmSwift
import Combine

final class PersistenceGatewayListenChangesetTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence.changeset")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory listen changeset test realm")
        persistence = PersistenceGateway(queue: queue, configuration: config)
    }
    
    override func tearDown() {
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
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
    
    func test_listenChangeset_update1_success() {
        // given
        let firstUser = createSameConfigUser(age: 0)
        let secondUser = createSameConfigUser(age: 1)
        let userToInsert = createSameConfigUser(age: 2)
        
        let users = [firstUser, secondUser]
        let expect = expectation(description: "listen.update1")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedUsersList = users + [userToInsert]
        var resultUsersList: [PrimaryKeyUser] = []
        
        persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                if resultUsersList.count == expectedUsersList.count {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        persistence.save(objects: users, mapper: domainMapper)
            .delay(for: 2, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: userToInsert, mapper: domainMapper)
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_update2_success() {
        // given
        let user1 = createSameConfigUser(age: 0)
        let user2 = createSameConfigUser(age: 1)
        let user3 = createSameConfigUser(age: 3)
        
        let users = [user1, user2, user3]
        let expect = expectation(description: "listen.update2")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedUsersList = [user1, user3]
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.delete(DonainRealmPrimaryMapper.self) { $0.filter("id = %@", user2.id) }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_update3_success() {
        // given
        let user1 = createSameConfigUser(age: 0)
        let user2 = createSameConfigUser(age: 1)
        let user3 = createSameConfigUser(age: 3)
        
        var modified = user2
        modified.name = "modified"
        
        let users = [user1, user2, user3]
        let expect = expectation(description: "listen.update3")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedUsersList = [user1, modified, user3]
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.save(object: modified, mapper: domainMapper)
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_update4_success() {
        // given
        let user1 = createSameConfigUser(age: 0)
        let user2 = createSameConfigUser(age: 1)
        let user3 = createSameConfigUser(age: 3)
        let userToInsert = createSameConfigUser(age: 2)
        
        let users = [user1, user2, user3]
        let expect = expectation(description: "listen.update4")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedUsersList = [user1, userToInsert, user3]
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    realm.delete(realm.objects(RealmPrimaryKeyUser.self).filter("id = %@", user2.id))
                    realm.add(domainMapper.convert(model: userToInsert), update: .all)
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_update5_success() {
        // given
        let user1 = createSameConfigUser(age: 0)
        let userToDelete = createSameConfigUser(age: 1)
        let user3 = createSameConfigUser(age: 3)
        let userToInsert = createSameConfigUser(age: 2)
        
        var modified = user3
        modified.name = "modified"
        
        let users = [user1, userToDelete, user3]
        let expect = expectation(description: "listen.update5")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedUsersList = [user1, userToInsert, modified]
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    realm.delete(realm.objects(RealmPrimaryKeyUser.self).filter("id = %@", userToDelete.id))
                    realm.add(domainMapper.convert(model: userToInsert), update: .all)
                    realm.add(domainMapper.convert(model: modified), update: .modified)
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_update_success() {
        // given
        let firstDeleteUser = createSameConfigUser(age: 0)
        let userToModify = createSameConfigUser(age: 1)
        let userToInsert1 = createSameConfigUser(age: 2)
        let middleDeleteUser = createSameConfigUser(age: 3)
        let simpleUser = createSameConfigUser(age: 4)
        let lastDeleteUser = createSameConfigUser(age: 5)
        let userToInsert2 = createSameConfigUser(age: 6)
        
        let users = [firstDeleteUser, userToModify, middleDeleteUser, simpleUser, lastDeleteUser]
        let expect = expectation(description: "listen")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        var modifiedUser = userToModify
        modifiedUser.name = "modified"
        let expectedUsersList = [modifiedUser, userToInsert1, simpleUser, userToInsert2]
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: users, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 2, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    realm.add(domainMapper.convert(model: userToInsert1), update: .all)
                    realm.add(domainMapper.convert(model: userToInsert2), update: .all)
                    realm.add(domainMapper.convert(model: modifiedUser), update: .modified)
                    let deleteIds = [firstDeleteUser, middleDeleteUser, lastDeleteUser].map(\.id)
                    realm.delete(realm.objects(RealmPrimaryKeyUser.self).filter("id IN %@", deleteIds))
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_aLotUpdates_success() {
        // given
        let startUsers = (0..<20).map(createSameConfigUser)
        let idsToDelete = (5..<10).map { $0 }
        let usersToInsert = (21..<25).map(createSameConfigUser)
        
        let expect = expectation(description: "listen.aLotUpdates")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedUsersList = Array(startUsers[0...4]) + Array(startUsers[10...]) + usersToInsert
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: startUsers, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    realm.delete(realm.objects(RealmPrimaryKeyUser.self).filter("id IN %@", idsToDelete.map(String.init)))
                    let objectsToInsert = usersToInsert.map(domainMapper.convert)
                    realm.add(objectsToInsert, update: .all)
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenChangeset_aLotUpdates2_success() {
        // given
        let startUsers = (0..<20).map(createSameConfigUser)
        let idsToDelete = (5..<10).map { $0 }
        let usersToInsert = (21..<25).map(createSameConfigUser)
        
        let expect = expectation(description: "listen.aLotUpdates2")
        let domainMapper = DonainRealmPrimaryMapper()
        let realmMapper = RealmDomainPrimaryMapper()
        
        let expectedListBeforeUpdate = Array(startUsers[0...4]) + Array(startUsers[10...]) + usersToInsert
        let idsToModify = [0, 3, 4, 12, 14, 16, 18]
        var usersToModified = idsToModify.map { expectedListBeforeUpdate[$0] }
        for index in 0..<usersToModified.count {
            usersToModified[index].name += " modified"
        }
        
        var expectedUsersList = Array(startUsers[0...4]) + Array(startUsers[10...]) + usersToInsert
        idsToModify.enumerated().forEach { offset, item in
            expectedUsersList[item] = usersToModified[offset]
        }
        
        var resultUsersList: [PrimaryKeyUser] = []
        var callCount = 0
        
        persistence.save(objects: startUsers, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenArrayChangesSet(mapper: realmMapper) { $0 }
            }
            .sink(receiveCompletion: { _ in }) { receivedChangeset in
                apply(changeset: receivedChangeset, to: &resultUsersList)
                callCount += 1
                if callCount == 2 {
                    resultUsersList = resultUsersList.sorted { $0.age < $1.age }
                    expect.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // when
        Just(())
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    realm.delete(realm.objects(RealmPrimaryKeyUser.self).filter("id IN %@", idsToDelete.map(String.init)))
                    let objectsToInsert = usersToInsert.map(domainMapper.convert)
                    realm.add(objectsToInsert, update: .all)
                    let objectsToModify = usersToModified.map(domainMapper.convert)
                    realm.add(objectsToModify, update: .modified)
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        // then
        waitForExpectations(timeout: 5)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    private func createUser(id: String = "\(UUID().hashValue)",  name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: id, name: name, age: age)
    }
    
    private func createSameConfigUser(age: Int) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: "\(age)", name: "\(age)", age: age)
    }
}

private func apply<T, Failure: Error>(changeset: PersistenceChangeset<T, Failure>, to array: inout [T]) {
    switch changeset {
    case let .initial(objects):
        array = objects
    case let .update(deleted, inserted, modified):
        deleted.reversed().forEach { array.remove(at: $0) }
        inserted.forEach { array.insert($0.item, at: $0.index) }
        modified.forEach { array[$0.index] = $0.item }
        
    case .error:
        break
    }
}
