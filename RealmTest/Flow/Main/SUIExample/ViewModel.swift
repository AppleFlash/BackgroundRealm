//
//  ViewModel.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

import Foundation
import Combine

final class ViewModel: ObservableObject {
	private let interactor = ListInteractor()
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
		
		interactor.listenUsersChangeSet()
			.sink { _ in } receiveValue: { [weak self] changeset in
				self?.handle(changeset: changeset)
			}
			.store(in: &subscriptions)
	}
	
	func didTap(user: User) {
		interactor.modify(user: user)
	}
	
	func deleteUser(at index: Int) {
		guard users.indices ~= index else {
			return
		}
		
		let id = users[index].id
		interactor.deleteUser(at: id)
	}
	
	func addUser() {
		interactor.addUser()
	}
	
	func addUsers() {
		interactor.addButchOfUsers()
	}
	
	private func handle(changeset: PersistenceChangeset<User>) {
		var array = userSubject.value
		changeset.apply(to: &array)
		userSubject.send(array)
	}
}
