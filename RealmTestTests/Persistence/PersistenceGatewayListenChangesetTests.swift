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
	private var listenScheduler: TestSchedulerOf<RunLoop>!
    
    override func setUp() {
        super.setUp()
        
		listenScheduler = RunLoop.test
        let config = Realm.Configuration(inMemoryIdentifier: "in memory listen changeset test realm \(UUID().uuidString)")
		persistence = PersistenceGateway(regularScheduler: .immediate, listenScheduler: listenScheduler.eraseToAnyScheduler(), configuration: config)
    }
    
    override func tearDown() {
		persistence.deleteAll()
        persistence = nil
        subscriptions.removeAll()
		listenScheduler = nil
        
        super.tearDown()
    }
    
    func test_listenChangeset_initial_success() {
        // given
        let users = (0..<3).map { createUser(id: "\($0)") }
        var changeset: PersistenceChangeset<PrimaryKeyUser>?
		let container = KeyedUserContainer(id: "1", users: users)
		let domainMapper = DomainRealmUsersKeyedContainerMapper(userMapper: .init())
		let realmMapper = RealmDomainPrimaryMapper()
		let expectation = expectation(description: "realm expectation")

        // when
        persistence.save(object: container, mapper: domainMapper)
            .flatMap {
				self.persistence.listenOrderedArrayChanges(
					RealmDomainKeyedUserContainerMapper.self,
					mapper: realmMapper,
					filterBlock: { $0.first?.usersList }
				)
            }
			.sink { _ in } receiveValue: {
				changeset = $0
				expectation.fulfill()
			}
            .store(in: &subscriptions)
		
		listenScheduler.run()

        // then
		waitForExpectations(timeout: 1)
        switch changeset {
        case let .initial(objects):
            XCTAssertEqual(objects, users)
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
			changeset.apply(to: &resultUsersList)
        })
        .store(in: &subscriptions)

		listenScheduler.advance()
		
        // when
		persistence.save(object: container, mapper: domainMapper)
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
            .flatMap {
				self.persistence.updateAction { realm in
                    let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
                    let index = list.usersList.index(matching: NSPredicate(format: "id = %@", users[0].id))!
                    let realmUser = DomainRealmPrimaryMapper().convert(model: modifiedUsers[0])
                    let obj = realm.create(RealmPrimaryKeyUser.self, value: realmUser, update: .all)
                    list.usersList[index] = obj
                }
            }
            .sink()
            .store(in: &subscriptions)
		
		listenScheduler.advance()

        // then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
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
			.flatMap {
				self.persistence.listenOrderedArrayChanges(
					RealmDomainKeyedUserContainerMapper.self,
					mapper: realmMapper,
					filterBlock: { $0.filter("id = %@", "1").first?.usersList }
				)
			}
			.handleEvents(receiveOutput: { _ in self.listenScheduler.advance() })
			.sink(receiveCompletion: { _ in }) { receivedChangeset in
				receivedChangeset.apply(to: &resultUsersList)
				callCount += 1
			}
			.store(in: &subscriptions)
		
		// when
		persistence
			.updateAction { realm in
				let mapper = DomainRealmPrimaryMapper()
				let list = realm.objects(RealmKeyedUserContainer.self).filter("id = %@", container.id).first!
				list.usersList.remove(atOffsets: .init(idsToDelete))
				
				let objectsToInsert = usersToInsert.map(mapper.convert).map { realm.create(RealmPrimaryKeyUser.self, value: $0, update: .all) }
				list.usersList.append(objectsIn: objectsToInsert)
				
				let objectsToModify = usersToModified.map(mapper.convert).map { realm.create(RealmPrimaryKeyUser.self, value: $0, update: .all) }
				zip(idsToModify, objectsToModify).forEach { mod, obj in
					list.usersList[mod] = obj
				}
			}
			.handleEvents(receiveOutput: { self.listenScheduler.advance() })
			.sink()
			.store(in: &subscriptions)
		
		// then
		_ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
		XCTAssertEqual(resultUsersList, expectedUsersList, file: file, line: line)
	}
    
    private func createUser(id: String = "\(UUID().hashValue)",  name: String = UUID().uuidString, age: Int = .random(in: 10...80)) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: id, name: name, age: age)
    }
    
    private func createSameConfigUser(age: Int) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: "\(age)", name: "\(age)", age: age)
    }
}
