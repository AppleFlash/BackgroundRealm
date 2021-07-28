//
//  main.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.07.2021.
//

import UIKit

private let testsAppDelegate = "TestsAppDelegate"

UIApplicationMain(
	CommandLine.argc,
	CommandLine.unsafeArgv,
	nil,
	NSClassFromString(testsAppDelegate) != nil ? testsAppDelegate : NSStringFromClass(AppDelegate.self)
)

