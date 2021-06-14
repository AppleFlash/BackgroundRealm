//
//  PersistenceGatewayCoomonTests.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 09.06.2021.
//

@testable import RealmTest
import XCTest
import RealmSwift
import Combine

// MARK: - Objects

private struct DumbObject: Equatable {
    let field: Int
}

final class RealmDumbObject: Object {
    @objc dynamic var field: Int = 0
}

// MARK: - Mappers

private struct DonainRealmDumbObjectMapper: ObjectToPersistenceMapper {
    func convert(model: DumbObject) -> RealmDumbObject {
        let user = RealmDumbObject()
        user.field = model.field
        
        return user
    }
}

private struct RealmDomainDumbObjectMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmDumbObject) -> DumbObject {
        return DumbObject(field: persistence.field)
    }
}

// MARK: - Test

final class PersistenceGatewayCoomonTests: XCTestCase {
    private var persistence: PersistenceGatewayProtocol!
    private var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        let queue = DispatchQueue(label: "com.test.persistence.common")
        let config = Realm.Configuration(inMemoryIdentifier: "in memory common test realm")
        persistence = PersistenceGateway(queue: queue, configuration: config)
    }
    
    override func tearDown() {
        persistence = nil
        subscriptions.removeAll()
        
        super.tearDown()
    }
    
    func test_callSaveFromMainReadFromMain_success() {
        // when
        XCTAssert(Thread.isMainThread)
        let object = DumbObject(field: 1)
        let expect = expectation(description: "save")
        var isReceiveOnMain: Bool?
        
        // given
        persistence.save(object: object, mapper: DonainRealmDumbObjectMapper())
            .receive(on: RunLoop.main)
            .flatMap { [persistence] in
                return persistence!.get(mapper: RealmDomainDumbObjectMapper())
            }
            .sink(receiveCompletion: { _ in
                isReceiveOnMain = Thread.isMainThread
                expect.fulfill()
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
        
        // then
        
        waitForExpectations(timeout: 2)
        XCTAssertNotNil(isReceiveOnMain)
        XCTAssertFalse(isReceiveOnMain ?? true)
    }
    
    func test_callSaveFromMainReadFromBackground_success() {
        // when
        XCTAssert(Thread.isMainThread)
        let object = DumbObject(field: 1)
        let expect = expectation(description: "save")
        var isReceiveOnMain: Bool?
        
        // given
        persistence.save(object: object, mapper: DonainRealmDumbObjectMapper())
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainDumbObjectMapper())
            }
            .sink(receiveCompletion: { _ in
                isReceiveOnMain = Thread.isMainThread
                expect.fulfill()
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
        
        // then
        
        waitForExpectations(timeout: 2)
        XCTAssertNotNil(isReceiveOnMain)
        XCTAssertFalse(isReceiveOnMain ?? true)
    }
    
    func test_callSaveFromBackgroundReadFromMain_success() {
        // when
        XCTAssert(Thread.isMainThread)
        let object = DumbObject(field: 1)
        let expect = expectation(description: "save")
        var isReceiveOnMain: Bool?
        
        // given
        Just(())
            .receive(on: DispatchQueue.global())
            .flatMap { [persistence] in
                persistence!.save(object: object, mapper: DonainRealmDumbObjectMapper())
            }
            .receive(on: RunLoop.main)
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainDumbObjectMapper())
            }
            .sink(receiveCompletion: { _ in
                isReceiveOnMain = Thread.isMainThread
                expect.fulfill()
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
        
        // then
        
        waitForExpectations(timeout: 2)
        XCTAssertNotNil(isReceiveOnMain)
        XCTAssertFalse(isReceiveOnMain ?? true)
    }
    
    func test_callSaveFromBackgroundReadFromBackground_success() {
        // when
        XCTAssert(Thread.isMainThread)
        let object = DumbObject(field: 1)
        let expect = expectation(description: "save")
        var isReceiveOnMain: Bool?
        
        // given
        Just(())
            .receive(on: DispatchQueue.global())
            .flatMap { [persistence] in
                persistence!.save(object: object, mapper: DonainRealmDumbObjectMapper())
            }
            .receive(on: DispatchQueue.global())
            .flatMap { [persistence] in
                persistence!.get(mapper: RealmDomainDumbObjectMapper())
            }
            .sink(receiveCompletion: { _ in
                isReceiveOnMain = Thread.isMainThread
                expect.fulfill()
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
        
        // then
        
        waitForExpectations(timeout: 2)
        XCTAssertNotNil(isReceiveOnMain)
        XCTAssertFalse(isReceiveOnMain ?? true)
    }
}
