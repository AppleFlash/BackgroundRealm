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

/// Тест кейсы по наблюдению за массивом объектов. Всегда возвращается диф изменений
final class PersistenceGatewayListenChangesetTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence.changeset")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory listen changeset test realm \(UUID().uuidString)")
        persistence = PersistenceGateway(scheduler: queue, configuration: config)
    }
    
    override func tearDown() {
		persistence.deleteAll()
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
    func test_listenChangeset_initial_success() {
        // given
        let users = (0..<3).map { createUser(id: "\($0)") }
        var changeset: PersistenceChangeset<PrimaryKeyUser>?
        let expect = expectation(description: "listen")
		let container = KeyedUserContainer(id: "1", users: users)
		let domainMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
		let realmMapper = RealmDomainPrimaryMapper()

        // when
        persistence.save(object: container, mapper: domainMapper)
            .flatMap { [persistence] in
                persistence!.listenOrderedArrayChanges(
					RealmDomainKeyedUserContainerMapper.self,
					mapper: realmMapper,
					filterBlock: { $0.first?.usersList }
				)
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
    
    func test_listenOrderedArrayChangeset_modify() {
        // given
        let firstUser = createSameConfigUser(age: 0)
        let secondUser = createSameConfigUser(age: 1)
        let users = [firstUser, secondUser]
        var modifiedUsers = users
        modifiedUsers[0].name = "updated \(modifiedUsers[0].name)"

        let container = KeyedUserContainer(id: "1", users: users)
        let domainMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
        let realmMapper = RealmDomainPrimaryMapper()

        let expectedUsersList = modifiedUsers
        var resultUsersList: [PrimaryKeyUser] = []

		persistence.listenOrderedArrayChanges(
			RealmDomainKeyedUserContainerMapper.self,
			mapper: realmMapper,
			filterBlock: { $0.filter("id = %@", "1").first?.usersList }
		)
        .sink(receiveCompletion: { _ in }, receiveValue: { changeset in
            apply(changeset: changeset, to: &resultUsersList)
        })
        .store(in: &subscriptions)

        // when
        Just(())
            .flatMap { [persistence] in
                persistence!.save(object: container, mapper: domainMapper)
            }
            .delay(for: 1, scheduler: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.updateAction { realm in
                    let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
                    let index = list.usersList.index(matching: NSPredicate(format: "id = %@", users[0].id))!
                    let realmUser = DonainRealmPrimaryMapper().convert(model: modifiedUsers[0])
                    let obj = realm.create(RealmPrimaryKeyUser.self, value: realmUser, update: .all)
                    list.usersList[index] = obj
                }
            }
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)

        // then
        _ = XCTWaiter.wait(for: [.init()], timeout: 2)
        XCTAssertEqual(resultUsersList, expectedUsersList)
    }
    
    func test_listenOrderedArrayChangeset_aLotUpdates2_success() {
        bigTest(modifications: [0, 3, 4, 12, 14, 16, 18])
    }
	
	func test_listenOrderedArrayChangeset_aLotUpdates3_success() {
		bigTest(modifications: [10, 11, 12, 13, 14, 15, 16])
	}
	
	func test_listenOrderedArrayChangeset_aLotUpdates4_success() {
		bigTest(modifications: [0, 1, 2, 3, 4, 5, 6])
	}
	
	private func bigTest(modifications: [Int], file: StaticString = #filePath, line: UInt = #line) {
		// given
		let startUsers = (0..<20).map(createSameConfigUser)
		let idsToDelete = (5..<10).map { $0 }
		let usersToInsert = (21..<25).map(createSameConfigUser)
		
		let container = KeyedUserContainer(id: "1", users: startUsers)
		
		let expect = expectation(description: "listen.aLotUpdates2")
		let domainMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
		let realmMapper = RealmDomainPrimaryMapper()
		
		let expectedListBeforeUpdate = Array(startUsers[0...4]) + Array(startUsers[10...]) + usersToInsert
		let idsToModify = modifications
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
		
		persistence.save(object: container, mapper: domainMapper)
			.flatMap { [persistence] in
				persistence!.listenOrderedArrayChanges(
					RealmDomainKeyedUserContainerMapper.self,
					mapper: realmMapper,
					filterBlock: { $0.filter("id = %@", "1").first?.usersList }
				)
			}
			.sink(receiveCompletion: { _ in }) { receivedChangeset in
				apply(changeset: receivedChangeset, to: &resultUsersList)
				callCount += 1
				if callCount == 2 {
					expect.fulfill()
				}
			}
			.store(in: &subscriptions)
		
		// when
		Just(())
			.delay(for: 1, scheduler: RunLoop.main)
			.flatMap { [persistence] in
				persistence!.updateAction { realm in
					let mapper = DonainRealmPrimaryMapper()
					let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
					list.usersList.remove(atOffsets: .init(idsToDelete))
		
					let objectsToInsert = usersToInsert.map(mapper.convert).map { realm.create(RealmPrimaryKeyUser.self, value: $0, update: .all) }
					list.usersList.append(objectsIn: objectsToInsert)
					
					let objectsToModify = usersToModified.map(mapper.convert).map { realm.create(RealmPrimaryKeyUser.self, value: $0, update: .all) }
					zip(idsToModify, objectsToModify).forEach { mod, obj in
						list.usersList[mod] = obj
					}
				}
			}
			.sink(receiveCompletion: { _ in }) { _ in }
			.store(in: &subscriptions)
		
		// then
		waitForExpectations(timeout: 2)
		XCTAssertEqual(resultUsersList, expectedUsersList, file: file, line: line)
	}
    
    private func createUser(id: String = "\(UUID().hashValue)",  name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: id, name: name, age: age)
    }
    
    private func createSameConfigUser(age: Int) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: "\(age)", name: "\(age)", age: age)
    }
}

private func apply<T>(changeset: PersistenceChangeset<T>, to array: inout [T]) {
    switch changeset {
    case let .initial(objects):
        array = objects
    case let .update(deleted, inserted):
        deleted.forEach { array.remove(at: $0) }
        inserted.forEach { array.insert($0.item, at: $0.index) }
    }
}
