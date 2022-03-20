//
//  MainCoordinator.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import UIKit
import SwiftUI

final class MainCoordinator {
	private let root: UINavigationController
	
	init(root: UINavigationController) {
		self.root = root
	}
	
	func start() {
		let items = [ListData<AppFlowCell>(header: "What would you like to see?", cells: [.swiftUI, .articleExample])]
		let listController = ListViewController(items: items)
		listController.selectHandler = { [weak listController] data in
			switch data {
			case .swiftUI:
				let swiftUIView = AnyView(ListView())
				let vc = UIHostingController(rootView: swiftUIView)
				listController?.navigationController?.pushViewController(vc, animated: true)

			case .articleExample:
				guard let listVc = listController else {
					fatalError("Root controller is deinited")
				}
				
				let coordinator = ArticleCoordinator(root: listVc)
				coordinator.start()
			}
		}
		
		root.viewControllers = [listController]
	}
}
