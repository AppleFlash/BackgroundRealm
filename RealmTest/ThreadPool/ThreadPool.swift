//
//  ThreadPool.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 18.08.2021.
//

import Foundation

final class ThreadPool {
	static let shared: ThreadPool = .init()
	
	private var mutex: pthread_mutex_t
	private var workers: [RunLoopThreadWorker] = []
	
	init() {
		self.mutex = pthread_mutex_t()
	}
	
	func start(name: String, block: @escaping () -> Void) -> ThreadWorker {
		pthread_mutex_lock(&mutex)
		workers.removeAll { $0.isCancelled }
		
		let worker: RunLoopThreadWorker
		if let runningWorker = workers.first(where: { !$0.isCancelled }) {
			worker = runningWorker
		} else {
			worker = RunLoopThreadWorker(name: name)
			workers.append(worker)
		}
		pthread_mutex_unlock(&mutex)
		
		worker.start(block)
		
		return worker
	}
	
	deinit {
		pthread_mutex_destroy(&mutex)
	}
}
