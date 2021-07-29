//
//  ViewController.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import UIKit
import Combine
import SwiftUI

struct ListView: View {
	@StateObject var viewModel = ViewModel()
	
	var body: some View {
		HStack {
			Button {
				viewModel.addUser()
			} label: {
				Text("Add user")
			}
			
			Button {
				viewModel.addUsers()
			} label: {
				Text("Add list of users")
			}
		}

		List {
			ForEach(viewModel.users) { user in
				Text(user.name).onTapGesture {
					viewModel.didTap(user: user)
				}
			}
			.onDelete { set in
				viewModel.deleteUser(at: set.first!)
			}
		}
	}
}

final class ViewModel: ObservableObject {
	private let userStorage = UserStorage()
	private var subscriptions = Set<AnyCancellable>()
	
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
			.flatMap { [userStorage] in
				userStorage.listenChangesetContainer()
			}
			.sink(receiveCompletion: { _ in }, receiveValue: { [unowned self] changeset in
				self.handle(changeset: changeset)
			})
			.store(in: &subscriptions)
	}
	
	private func handle(changeset: PersistenceChangeset<User>) {
		switch changeset {
		case let .initial(users):
			userSubject.send(users)
		case let .update(deleted, inserted):
			var users = userSubject.value
			deleted.forEach { users.remove(at: $0) }
			inserted.forEach { users.insert($0.item, at: $0.index) }
			userSubject.send(users)
		}
	}
	
	func didTap(user: User) {
		var changedUser = user
		changedUser.name = "m" + changedUser.name
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
		let user = User(id: id, name: "user \(id.uuidString)")
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
		
		let users = ids.map { User(id: $0, name: "user \($0.uuidString)") }
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
}

extension Publisher {
	func sink() -> AnyCancellable {
		return sink(receiveCompletion: { _ in }, receiveValue: { _ in })
	}
}
