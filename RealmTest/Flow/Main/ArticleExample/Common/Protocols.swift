//
//  Protocols.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import Foundation
import Combine

protocol UserSerivceProtocol: AnyObject {
	func loadUser(at id: UUID) -> AnyPublisher<Void, Error>
	func update(user: Domain.User) -> AnyPublisher<Void, Error>
}

protocol ViewOutput: AnyObject {
	var user: AnyPublisher<Domain.User, Never> { get }
	func update(name: String)
}

protocol UserViewRepositoryProtocol: AnyObject {
	func listen(at id: UUID) -> AnyPublisher<Domain.User?, Error>
}

protocol UserServiceRepositoryProtocol: AnyObject {
	func save(_ user: Domain.User) -> AnyPublisher<Void, Error>
	func save(_ user: API.User) -> AnyPublisher<Void, Error>
}

typealias UserDetailsRepositoryProtocol = UserViewRepositoryProtocol & UserServiceRepositoryProtocol
