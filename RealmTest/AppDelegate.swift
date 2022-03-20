//
//  AppDelegate.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import UIKit
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		window = UIWindow(frame: UIScreen.main.bounds)
		let nav = UINavigationController()

//		let swiftUIView = AnyView(ListView())
//		let view = UIHostingController(rootView: swiftUIView)
//		nav.viewControllers = [view]
		
//		let persistence = PersistenceGateway(regularScheduler: DispatchQueue.global().eraseToAnyScheduler(), listenScheduler: .main, configuration: .defaultConfiguration)
//		let mapper = Mapper()
//		let repo = UserDetailsRepository(persistence: persistence, mapper: mapper)
//		let service = New.UserService(repository: repo)
//		let viewModel = New.UserDetailsViewModel(repository: repo, service: service)
//		let vc = ViewContoller(output: viewModel)
//		nav.viewControllers = [vc]
		
//		let storage = Old.UserStorage()
//		let service = Old.UserService(storage: storage)
//		let viewModel = Old.UserDetailsViewModel(storage: storage, service: service)
//		let vc = ViewContoller(output: viewModel)
//		nav.viewControllers = [vc]

		window?.rootViewController = nav
		window?.makeKeyAndVisible()
		
		let coordinator = MainCoordinator(root: nav)
		coordinator.start()
		
        return true
    }
}
