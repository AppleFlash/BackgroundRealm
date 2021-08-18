//
//  ViewModel.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

import Foundation
import Combine

final class ViewModel: ObservableObject {
	private let userStorage = UserStorage()
	private var subscriptions = Set<AnyCancellable>()
	private var cancel1: AnyCancellable?
	private var cancel2: AnyCancellable?
	
	private let userSubject = CurrentValueSubject<[User], Never>([])
	
	@Published var users: [User] = []
	
	init() {
		viewDidLoad()
	}
	
	func viewDidLoad() {
		userSubject
			.removeDuplicates()
			.receive(on: RunLoop.main)
			.sink { [weak self] users in
				self?.users = users
			}
			.store(in: &subscriptions)
		
		userStorage.saveContainer()
//			.flatMap { [weak self] _ in
//				self?.startListen()
//			}
			.sink(receiveCompletion: { _ in }, receiveValue: { [unowned self] _ in
				self.startListen()
//				self.startListen2()
			})
			.store(in: &subscriptions)
	}
	
	private func startListen() {
		print("DEBUG: Res 1 = Will start")

		cancel1 = userStorage.listenChangesetContainer()
			.handleEvents(receiveCompletion: { res in
				print("DEBUG: Res 1 = \(res)")
			})
			.sink(
				receiveCompletion: { [weak self] res in
					switch res {
					case .failure:
						self?.startListen()
					case .finished:
						break
					}
				},
				receiveValue: { [unowned self] changeset in
					print("update1. Thread = \(Thread.current.name)")
					self.handle(changeset: changeset)
				}
			)
		
		cancel2 = userStorage.listenChangesetContainer()
			.handleEvents(receiveCompletion: { res in
				print("Res 2 = \(res)")
			})
			.sink(
				receiveCompletion: { [weak self] res in
					switch res {
					case .failure:
						print("cancel1 = \(self!.cancel1), cancel2 = \(self!.cancel2),")
					case .finished:
						break
					}
				},
				receiveValue: { [unowned self] changeset in
					print("update2. Thread = \(Thread.current.name)")
				}
			)
	}
	
	private func startListen2() {
		userStorage.listenChangesetContainer()
			.handleEvents(receiveCompletion: { res in
				print("Res 2 = \(res)")
			})
			.sink(
				receiveCompletion: { [weak self] res in
					switch res {
					case .failure:
						self?.startListen2()
					case .finished:
						break
					}
				},
				receiveValue: { [unowned self] changeset in
					print("update2. Thread = \(Thread.current.name)")
				}
			)
			.store(in: &subscriptions)
	}
	
	func didTap(user: User) {
		var changedUser = user
		var oldCount = changedUser.modifyCount ?? 0
		changedUser.modifyCount = oldCount + 1
		
		userStorage.updateInContainer(user: changedUser)
			.sink { result in
				switch result {
				case .finished:
					print("user \(user.id.uuidString) did update")
				case let .failure(error):
					print("update error \(error)")
				}
			} receiveValue: {}
			.store(in: &subscriptions)
	}
	
	func deleteUser(at index: Int) {
		guard users.indices ~= index else {
			return
		}
		
		let id = users[index].id
		userStorage.deleteFromContainer(userAt: id)
			.sink { result in
				switch result {
				case .finished:
					print("user \(id.uuidString) did delete")
				case let .failure(error):
					print("delete error \(error)")
				}
			} receiveValue: {}
			.store(in: &subscriptions)
	}
	
	func addUser() {
		let id = UUID()
		let roleIndex = Int.random(in: 0..<Role.allCases.count)
		let role = Role.allCases[roleIndex]
		
		let user = User(id: id, role: role, name: "user \(id.uuidString)", modifyCount: nil)
		userStorage.saveToContainer(user: user)
			.sink { result in
				switch result {
				case .finished:
					print("user \(id.uuidString) did save")
				case let .failure(error):
					print("save error \(error)")
				}
			} receiveValue: {}
			.store(in: &subscriptions)
	}
	
	func addUsers() {
		let ids = (0...3).map { _ in UUID() }
		
		let users: [User] = ids.map {
			let roleIndex = Int.random(in: 0..<Role.allCases.count)
			let role = Role.allCases[roleIndex]
			return User(id: $0, role: role, name: "user \($0.uuidString)", modifyCount: nil)
		}
		userStorage.saveToContainer(users: users)
			.sink { result in
				switch result {
				case .finished:
					print("users \(ids.map { $0.uuidString }) did save")
				case let .failure(error):
					print("save error \(error)")
				}
			} receiveValue: {}
			.store(in: &subscriptions)
	}
	
	private func handle(changeset: PersistenceChangeset<User>) {
		var array = userSubject.value
		changeset.apply(to: &array)
		userSubject.send(array)
	}
}
