//
//  TestsAppDelegate.swift
//  RealmTestTests
//
//  Created by Vladislav Sedinkin on 28.07.2021.
//

import UIKit

@objc(TestsAppDelegate)
class TestsAppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		window = UIWindow(frame: UIScreen.main.bounds)
		window?.rootViewController = UIViewController()
		window?.makeKeyAndVisible()
		return true
	}
}
