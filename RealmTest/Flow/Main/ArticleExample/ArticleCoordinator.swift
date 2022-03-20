//
//  ArticleCoordinator.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import UIKit

final class ArticleCoordinator {
	private let root: UIViewController
	
	init(root: UIViewController) {
		self.root = root
	}
	
	func start() {
		let items = [ListData<ApproachCell>(header: "Realm work approaches", cells: [.old, .new])]
		let listController = ListViewController(items: items)
		listController.selectHandler = { [weak listController] data in
			switch data {
			case .old:
				let storage = Old.UserStorage()
				let service = Old.UserService(storage: storage)
				let viewModel = Old.UserDetailsViewModel(storage: storage, service: service)
				let vc = ExampleViewContoller(output: viewModel)
				listController?.navigationController?.pushViewController(vc, animated: true)

			case .new:
				let persistence = PersistenceGateway(
					regularScheduler: DispatchQueue.global().eraseToAnyScheduler(),
					listenScheduler: .main,
					configuration: .defaultConfiguration
				)
				let mapper = Mapper()
				let repository = New.UserDetailsRepository(persistence: persistence, mapper: mapper)
				let service = New.UserService(repository: repository)
				let viewModel = New.UserDetailsViewModel(repository: repository, service: service)
				let vc = ExampleViewContoller(output: viewModel)
				listController?.navigationController?.pushViewController(vc, animated: true)
			}
		}
		
		root.navigationController?.pushViewController(listController, animated: true)
	}
}
