//
//  New.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import RealmSwift
import Combine
import Foundation

enum New {}

// MARK: - Repository

extension New {
	final class UserDetailsRepository: UserDetailsRepositoryProtocol {
		private let persistence: PersistenceGatewayProtocol
		private let mapper: MapperProtocol
		
		init(
			persistence: PersistenceGatewayProtocol,
			mapper: MapperProtocol
		) {
			self.persistence = persistence
			self.mapper = mapper
		}
		
		func save(_ user: API.User) -> AnyPublisher<Void, Error> {
			persistence.save(object: user, mapper: mapper.mapApiToRealm, update: .all)
		}
		
		func save(_ user: Domain.User) -> AnyPublisher<Void, Error> {
			persistence.save(object: user, mapper: mapper.mapDomainToRealm, update: .all)
		}
		
		func listen(at id: UUID) -> AnyPublisher<Domain.User?, Error> {
			persistence.listen(mapper: mapper.mapRealmToDomain) { results in
				return results.filter(NSPredicate(format: "id = %@", id.uuidString))
			}
		}
	}
}

// MARK: - Service

extension New {
	final class UserService: UserSerivceProtocol {
		private let repository: UserServiceRepositoryProtocol
		
		init(repository: UserDetailsRepositoryProtocol) {
			self.repository = repository
		}
		
		func loadUser(at id: UUID) -> AnyPublisher<Void, Error> {
			Result.Publisher(())
				.delay(for: 1, scheduler: DispatchQueue.global())
				.flatMap { [repository] _ -> AnyPublisher<Void, Error> in
					let user = API.User(id: id, role: Role.employee.rawValue, name: "George")
					return repository.save(user)
				}
				.eraseToAnyPublisher()
		}
		
		func update(user: Domain.User) -> AnyPublisher<Void, Error> {
			Result.Publisher(())
				.delay(for: .microseconds(100), scheduler: DispatchQueue.global())
				.flatMap { [repository] _ -> AnyPublisher<Void, Error> in
					return repository.save(user)
				}
				.eraseToAnyPublisher()
		}
	}
}

// MARK: - ViewModel

extension New {
	final class UserDetailsViewModel: ViewOutput {
		private let repository: UserViewRepositoryProtocol
		private let service: UserSerivceProtocol
		private let userId = UUID()
		
		private var subscriptions = Set<AnyCancellable>()
		private var userSubject = CurrentValueSubject<Domain.User?, Error>(nil)
		
		init(repository: UserDetailsRepositoryProtocol, service: UserSerivceProtocol) {
			self.repository = repository
			self.service = service
			
			start()
		}
		
		private func start() {
			listenUser()
			loadUser()
		}
		
		private func listenUser() {
			repository
				.listen(at: userId)
				.sink(
					receiveCompletion: { _ in },
					receiveValue: { [userSubject] user in
						userSubject.send(user)
					}
				)
				.store(in: &subscriptions)
		}
		
		private func loadUser() {
			service
				.loadUser(at: userId)
				.sink(
					receiveCompletion: { print("Handle result \($0)") },
					receiveValue: {}
				)
				.store(in: &subscriptions)
		}
		
		var user: AnyPublisher<Domain.User, Never> {
			userSubject
				.replaceError(with: nil)
				.compactMap { $0 }
				.receive(on: RunLoop.main)
				.eraseToAnyPublisher()
		}
		
		func update(name: String) {
			guard var user = userSubject.value else {
				return
			}
			
			user.name = name
			service
				.update(user: user)
				.sink(
					receiveCompletion: { _ in print("Handle update") },
					receiveValue: {}
				)
				.store(in: &subscriptions)
		}
	}
}
