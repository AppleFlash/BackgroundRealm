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

		let swiftUIView = AnyView(ListView())
		let view = UIHostingController(rootView: swiftUIView)
		nav.viewControllers = [view]

		window?.rootViewController = nav
		window?.makeKeyAndVisible()
		
//		let count = 20
//		var workers: [ThreadWorker] = []
//		DispatchQueue.concurrentPerform(iterations: count) { operation in
//			let worker = ThreadPool.shared.start(name: "TestThread \(operation)") {
//				print("Operation #\(operation) has executed on thread \(Thread.current.name)")
//			}
//			workers.append(worker)
//		}
//
//		Thread.sleep(forTimeInterval: 2)
//		print("Will start STOP operation")
//
//		DispatchQueue.concurrentPerform(iterations: count) { operation in
//			workers[operation].stop()
//		}
		
		
        return true
    }
}
