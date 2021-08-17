//
//  RunLoopThreadWorker.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 18.08.2021.
//

import Foundation

protocol ThreadWorker: AnyObject {
	func stop()
}

final class RunLoopThreadWorker: NSObject {
	private let name: String
	private var mutex: pthread_mutex_t
	
	private var operationsCount: UInt = 0
	private var block: (() -> Void)?
	private var _thread: Thread?
	private var liveThread: Thread {
		if let thread = _thread {
			return thread
		} else {
			let thread = Thread(target: self, selector: #selector(performThreadWork), object: nil)
			thread.name = "\(name)-\(UUID().uuidString)"
			_thread = thread
			return thread
		}
	}
	var isCancelled: Bool {
		return _thread?.isCancelled ?? false
	}
	
	init(name: String) {
		self.name = name
		self.mutex = pthread_mutex_t()
		
		super.init()
	}
	
	deinit {
		pthread_mutex_destroy(&mutex)
	}
	
	func start(_ block: @escaping () -> Void) {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }
		
		self.block = block
		operationsCount = max(1, operationsCount &+ 1)
		if liveThread.isFinished || liveThread.isCancelled {
			assertionFailure("Try to start finished or cancelled thread")
		}
		if !liveThread.isExecuting {
			liveThread.start()
		}
		
		perform(
			#selector(runBlock),
			on: liveThread,
			with: nil,
			waitUntilDone: false,
			modes: [RunLoop.Mode.default.rawValue]
		)
	}
}

extension RunLoopThreadWorker: ThreadWorker {
	func stop() {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }
		
		operationsCount = max(0, operationsCount - 1)
		if operationsCount == 0 {
			_thread?.cancel()
		}
	}
}

private extension RunLoopThreadWorker {
	@objc func runBlock() {
		block?()
	}
	
	@objc func performThreadWork() {
		while !(_thread?.isCancelled ?? false) {
			RunLoop.current.run(
				mode: .default,
				before: .distantFuture
			)
		}
		pthread_mutex_lock(&mutex)
		Thread.exit()
		pthread_mutex_unlock(&mutex)
	}
}
