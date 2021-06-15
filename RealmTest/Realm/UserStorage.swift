//
//  UserStorage.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 01.06.2021.
//

import Foundation
import RealmSwift
import Combine

final class UserStorage {
    private let gateway: PersistenceGateway<DispatchQueue>
//    private lazy var closureGateway = PersistenceClosureGateway(queue: DispatchQueue(label: "com.user.closure.persistence"))
    
    init() {
        let queue = DispatchQueue(label: "com.user.persistence")
        let config = Realm.Configuration(objectTypes: [RealmUser.self])
        gateway = PersistenceGateway(scheduler: queue, configuration: config)
    }
    
    func update(user: User) -> AnySinglePublisher<Void, Error> {
        return gateway.save(object: user, mapper: UserMapper(), update: .modified)
    }
    
    func save(user: APIUser) -> AnySinglePublisher<Void, Error> {
        return gateway.save(object: user, mapper: APIUserMapper(), update: .all)
    }
    
    func getUser(id: String) -> AnySinglePublisher<User?, Error> {
        return gateway.get(mapper: RealmUserMapper()) { $0.filter("id = %@", id) }
    }
    
    func listenUser(id: String) -> AnyPublisher<User, Error> {
        return gateway.listen(mapper: RealmUserMapper()) { $0.filter("id = %@", id) }
    }
    
    func update(id: String) -> AnySinglePublisher<Void, Error> {
        return gateway.updateAction { realm in
            let user = realm.object(ofType: RealmUser.self, forPrimaryKey: id)!
            user.name = "update block name"
            
            let user2 = realm.object(ofType: RealmUser.self, forPrimaryKey: "ECF493DB-4EA2-4D93-9C7B-C9643634F576")!
            user2.name = "\(user2.name) updated"
        }
    }
    
    func delete(id: String) -> AnySinglePublisher<Void, Error> {
        return gateway.delete(UserMapper.self) { $0.filter("id = %@", id) }
    }
    
    func getWithClosure(id: String, completion: @escaping (Result<User, Error>) -> Void) {
//        closureGateway.get(mapper: RealmUserMapper(), filterBlock: { $0.filter("id = %@", id) }, completion: completion)
    }
    
//    func delete(user: User) -> AnyPublisher<Void, Error> {
//        return gateway.delete(object: user, mapper: UserMapper())
//    }
}
