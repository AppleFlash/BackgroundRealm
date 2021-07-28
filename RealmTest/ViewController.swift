//
//  ViewController.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import UIKit
import Combine

let ID = "3B3267DC-A544-42D4-AC99-74EEE41F4CA8"

class ViewController: UIViewController {
	@IBOutlet private  weak var tableView: UITableView!
	private var subscriptions = Set<AnyCancellable>()
	private let viewModel = ViewModel()
	private let cellId = "myCellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()

		viewModel.viewDidLoad()
		configureTableView()
		subscribeToUpdates()
    }
	
	func configureTableView() {
		tableView.delegate = self
		tableView.dataSource = self
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
	}
	
	func subscribeToUpdates() {
		viewModel.usersChanges
			.receive(on: RunLoop.main)
			.sink { [tableView] users in
				tableView?.reloadData()
			}
			.store(in: &subscriptions)
	}
	
	@IBAction func addUser(_ sender: Any) {
		viewModel.addUser()
	}
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.users.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
		let user = viewModel.users[indexPath.row]
		cell.textLabel?.text = user.name
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		viewModel.didTap(user: viewModel.users[indexPath.row])
	}
	
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else {
			return
		}
		
		viewModel.deleteUser(at: indexPath.row)
	}
}

final class ViewModel {
	private let userStorage = UserStorage()
	private var subscriptions = Set<AnyCancellable>()
	
	private let userSubject = CurrentValueSubject<[User], Never>([])
	
	var users: [User] {
		return userSubject.value
	}
	
	var usersChanges: AnyPublisher<[User], Never> {
		return userSubject.removeDuplicates().eraseToAnyPublisher()
	}
	
	func viewDidLoad() {
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
}

extension Publisher {
	func sink() -> AnyCancellable {
		return sink(receiveCompletion: { _ in }, receiveValue: { _ in })
	}
}
