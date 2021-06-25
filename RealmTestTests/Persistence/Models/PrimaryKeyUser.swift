//
//  PrimaryKeyUser.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 12.06.2021.
//

@testable import RealmTest
import Foundation
import RealmSwift

struct PrimaryKeyUser: Equatable {
    let id: String
    var name: String
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

struct DonainRealmPrimaryMapper: ObjectToPersistenceMapper {
    func convert(model: PrimaryKeyUser) -> RealmPrimaryKeyUser {
        let user = RealmPrimaryKeyUser()
        user.id = model.id
        user.age = model.age
        user.name = model.name
        
        return user
    }
}

struct RealmDomainPrimaryMapper: PersistenceToDomainMapper {
    func convert(persistence: RealmPrimaryKeyUser) -> PrimaryKeyUser {
        return PrimaryKeyUser(id: persistence.id, name: persistence.name, age: persistence.age)
    }
}

///

struct UserContainer: Equatable {
    let users: [PrimaryKeyUser]
}

final class RealmUserContainer: Object {
    let usersList = List<RealmPrimaryKeyUser>()
}

struct DomainRealmUsersContainerMapper: ObjectToPersistenceMapper {
    private let userMapper: DonainRealmPrimaryMapper
    
    init(userMapper: DonainRealmPrimaryMapper) {
        self.userMapper = userMapper
    }
    
    func convert(model: UserContainer) -> RealmUserContainer {
        let users = model.users.map(userMapper.convert)
        let container = RealmUserContainer()
        container.usersList.append(objectsIn: users)
        
        return container
    }
}

struct RealmDomainUserContainerMapper: PersistenceToDomainMapper {
    private let userMapper: RealmDomainPrimaryMapper
    
    init(userMapper: RealmDomainPrimaryMapper) {
        self.userMapper = userMapper
    }
    
    func convert(persistence: RealmUserContainer) -> UserContainer {
        let users = persistence.usersList.map(userMapper.convert)
        return .init(users: Array(users))
    }
}

//

struct KeyedUserContainer: Equatable {
    let id: String
    let users: [PrimaryKeyUser]
}

final class RealmKeyedUserContainer: Object {
    @objc dynamic var id: String = ""
    let usersList = List<RealmPrimaryKeyUser>()
    
    override class func primaryKey() -> String? {
        return #keyPath(id)
    }
}

struct DomainRealmUsersKeyedContainerMapper: ObjectToPersistenceMapper {
    private let userMapper: DonainRealmPrimaryMapper
    
    init(userMapper: DonainRealmPrimaryMapper) {
        self.userMapper = userMapper
    }
    
    func convert(model: KeyedUserContainer) -> RealmKeyedUserContainer {
        let users = model.users.map(userMapper.convert)
        let container = RealmKeyedUserContainer()
        container.id = model.id
        container.usersList.append(objectsIn: users)
        
        return container
    }
}

struct RealmDomainKeyedUserContainerMapper: PersistenceToDomainMapper {
    private let userMapper: RealmDomainPrimaryMapper
    
    init(userMapper: RealmDomainPrimaryMapper) {
        self.userMapper = userMapper
    }
    
    func convert(persistence: RealmKeyedUserContainer) -> KeyedUserContainer {
        let users = persistence.usersList.map(userMapper.convert)
        return .init(id: persistence.id, users: Array(users))
    }
}

