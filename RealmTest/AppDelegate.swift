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
        return true
    }


}

