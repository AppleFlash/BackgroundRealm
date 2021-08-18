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

class MyThread: Thread {
	public enum State: String {
		case waiting = "isWaiting"
		case executing = "isExecuting"
		case finished = "isFinished"
		case cancelled = "isCancelled"
	}
	
	open var state: State = State.waiting {
		willSet {
			willChangeValue(forKey: State.executing.rawValue)
			willChangeValue(forKey: State.finished.rawValue)
			willChangeValue(forKey: State.cancelled.rawValue)
		}
		didSet {
			switch self.state {
			case .waiting:
				assert(oldValue == .waiting, "Invalid change from \(oldValue) to \(self.state)")
			case .executing:
				assert(
					oldValue == .waiting,
					"Invalid change from \(oldValue) to \(self.state)"
				)
			case .finished:
				//					assert(oldValue != .cancelled, "Invalid change from \(oldValue) to \(self.state)")
				break
			case .cancelled:
				break
			}
			
			didChangeValue(forKey: State.cancelled.rawValue)
			didChangeValue(forKey: State.finished.rawValue)
			didChangeValue(forKey: State.executing.rawValue)
		}
	}
	
	open override var isExecuting: Bool {
		if self.state == .waiting {
			return super.isExecuting
		} else {
			return self.state == .executing
		}
	}
	
	open override var isFinished: Bool {
		if self.state == .waiting {
			return super.isFinished
		} else {
			return self.state == .finished
		}
	}
	
	open override var isCancelled: Bool {
		if self.state == .waiting {
			return super.isCancelled
		} else {
			return self.state == .cancelled
		}
	}
	
	override func main() {
		print("")
		while isExecuting {
			RunLoop.current.run(
				mode: .default,
				before: .distantFuture
			)
		}
//		state = .finished
		print("thread stopped")
	}
	
	override func cancel() {
		state = .finished
		super.cancel()
//		CFRunLoopStop(CFRunLoopGetCurrent())
//
//		super.cancel()
	}
	
	deinit {
		print("deinit thread \(name)")
	}
}

final class RunLoopThreadWorker: NSObject {
	private let name: String
	private lazy var lock = NSLock()
	
	private var operationsCount: UInt = 0
	private var block: (() -> Void)?
	private var _thread: Thread?
	private var liveThread: Thread {
		if let thread = _thread {
			return thread
		} else {
			let thread = MyThread()
//			let thread = MyThread { [weak self] in
//				self?.performThreadWork()
//			}
			thread.name = "\(name)-\(UUID().uuidString)"
			_thread = thread
			return thread
		}
	}
	var isCancelled: Bool {
		return _thread?.isCancelled ?? false
	}
	
	var isExecuting: Bool {
		return _thread?.isExecuting ?? false
	}
	
	init(name: String) {
		self.name = name
		
		super.init()
	}
	
	func start(_ block: @escaping () -> Void) {
		lock.lock()
		defer { lock.unlock() }
		
		self.block = block
		operationsCount = max(1, operationsCount &+ 1)
		print("*** Start. Operations count = \(operationsCount) on thread: \(Thread.current.name) ***")
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
	
	deinit {
		print("")
	}
}

extension RunLoopThreadWorker: ThreadWorker {
	func stop() {
		lock.lock()
		defer { lock.unlock() }
		
		operationsCount = max(0, operationsCount - 1)
		print("*** Stop. Operations count = \(operationsCount) on thread: \(_thread?.name) ***")
		if operationsCount == 0 {
			print("DEBUG: WORK WILL CANCEL. Thread exists \(_thread != nil)")
			_thread?.cancel()
//			isRun = false
		}
	}
}

private extension RunLoopThreadWorker {
	@objc func runBlock() {
		block?()
	}
	
	@objc func performThreadWork() {
//		while true {
//		while !(_thread?.isCancelled ?? false) {
//			RunLoop.current.run(
//				mode: .default,
//				before: .distantFuture
//			)
//		}
//		print("==== WORK IS CANCELLED ====")
//		lock.lock()
////		pthread_mutex_lock(&mutex)
//		MyThread.exit()
//		_thread = nil
//		lock.unlock()
//		pthread_mutex_unlock(&mutex)
	}
}
