//
//  Old.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import RealmSwift
import Combine
import Foundation

enum Old {}

// MARK: - Storage

extension Old {
	final class UserStorage {
		private let realm: Realm
		
		init() {
			realm = try! Realm(configuration: .defaultConfiguration)
		}
		
		func save(realmUser: RealmUser) -> AnyPublisher<Void, Error> {
			Just(realmUser)
				.setFailureType(to: Error.self)
				.threadSafeReference()
				.handleEvents(receiveOutput: { [weak self] user in
					guard let self = self else {
						return
					}

					let realm = try! Realm(configuration: .defaultConfiguration)
					try! realm.write {
						realm.add(user, update: .all)
					}
					DispatchQueue.main.async {
						self.realm.refresh()
					}
				})
				.map { _ in }
				.eraseToAnyPublisher()
		}
		
		func user(at id: UUID) -> Results<RealmUser> {
			return realm.objects(RealmUser.self).filter(NSPredicate(format: "id = %@", id.uuidString))
		}
	}
}

// MARK: - Service

extension Old {
	final class UserService: UserSerivceProtocol {
		private let storage: UserStorage
		private let mapper = Mapper()
		
		init(storage: UserStorage) {
			self.storage = storage
		}
		
		func loadUser(at id: UUID) -> AnyPublisher<Void, Error> {
			Result.Publisher(())
				.delay(for: 1, scheduler: DispatchQueue.global())
				.flatMap { [storage, mapper] _ -> AnyPublisher<Void, Error> in
					let user = API.User(id: id, role: Role.employee.rawValue, name: "George")
					let realmUser = mapper.mapApiToRealm(user)
					return storage.save(realmUser: realmUser)
				}
				.eraseToAnyPublisher()
		}
		
		func update(user: Domain.User) -> AnyPublisher<Void, Error> {
			Result.Publisher(())
				.delay(for: .microseconds(100), scheduler: DispatchQueue.global())
				.flatMap { [storage, mapper] _ -> AnyPublisher<Void, Error> in
					let realmUser = mapper.mapDomainToRealm(user)
					return storage.save(realmUser: realmUser)
				}
				.eraseToAnyPublisher()
		}
	}
}

// MARK: - ViewModel

extension Old {
	final class UserDetailsViewModel: ViewOutput {
		private let storage: UserStorage
		private let service: UserSerivceProtocol
		private let mapper = Mapper()
		private let userId = UUID()
		
		private var subscriptions = Set<AnyCancellable>()
		private var userSubject = CurrentValueSubject<Domain.User?, Error>(nil)
		private var token: NotificationToken?
		private lazy var results: Results<RealmUser> = storage.user(at: userId)
		
		init(storage: UserStorage, service: UserSerivceProtocol) {
			self.storage = storage
			self.service = service
			start()
		}
		
		private func start() {
			listenUser()
			loadUser()
		}
		
		private func listenUser() {
			token = results.observe { [weak self] _ in
				guard let self = self else {
					return
				}

				guard let realmUser = self.results.first else {
					return
				}
				let user = self.mapper.mapRealmToDomain(realmUser)
				self.userSubject.send(user)
			}
		}
		
		private func loadUser() {
			service
				.loadUser(at: userId)
				.sink(
					receiveCompletion: {
						print("Handle result \($0)")
					},
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
					receiveCompletion: { _ in
						print("Handle update")
					},
					receiveValue: {}
				)
				.store(in: &subscriptions)
		}
	}
}
