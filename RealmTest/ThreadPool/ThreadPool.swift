//
//  ThreadPool.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 18.08.2021.
//

import Foundation

final class ThreadPool {
	static let shared: ThreadPool = .init()
	
	private let lock = NSLock()
	private var workers = NSHashTable<RunLoopThreadWorker>.weakObjects()
	
	private init() {
	}
	
	func start(name: String, block: @escaping () -> Void) -> ThreadWorker {
		lock.lock()
		defer {
			lock.unlock()
		}
//		workers.removeAll { $0.isCancelled }
		workers.allObjects.filter { !$0.isExecuting }.forEach {
			workers.remove($0)
		}
		
		let worker: RunLoopThreadWorker
		if let runningWorker = workers.allObjects.first(where: \.isExecuting) {
			print("DEBUG: Use existing worker for '\(name)'")
			worker = runningWorker
		} else {
			print("DEBUG: Create new worker for '\(name)'")
			worker = RunLoopThreadWorker(name: name)
//			workers.allObjects.append(worker)
			workers.add(worker)
		}
		
		worker.start(block)
		
		return worker
	}
}
