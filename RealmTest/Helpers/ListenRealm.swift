//
//  ListenRealm.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 17.08.2021.
//

import Combine
import RealmSwift
import Foundation

enum ListenOn {
	case scheduler(AnySchedulerOf<RunLoop>)
	case thread
}

extension Publishers {
	struct ListenRealm: Publisher {
		typealias Output = Realm
		typealias Failure = Error
		
		let config: Realm.Configuration
		let listenOn: ListenOn
		
		init(config: Realm.Configuration, listenOn: ListenOn) {
			self.config = config
			self.listenOn = listenOn
		}
		
		func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
			let subscription = Inner(publisher: self, subscriber: subscriber)
			subscriber.receive(subscription: subscription)
		}
	}
}

private extension Publishers.ListenRealm {
	final class Inner<S: Subscriber> where S.Input == Output, S.Failure == Failure {
		typealias Input = Realm.Configuration
		typealias Failure = Error
		
		private let publisher: Publishers.ListenRealm
		private var subscriber: S?
		private var worker: ThreadWorker?
		
		init(publisher: Publishers.ListenRealm, subscriber: S) {
			self.publisher = publisher
			self.subscriber = subscriber
			
			switch publisher.listenOn {
			case .thread:
				worker = ThreadPool.shared.start(name: "ListenBGRealm") { [weak self] in
					self?.createRealm()
				}
			case let .scheduler(scheduler):
				scheduler.schedule { [weak self] in
					self?.createRealm()
				}
			}
		}
		
		private func createRealm() {
			do {
				let _realm = try Realm(configuration: publisher.config)
				_ = subscriber?.receive(_realm)
			} catch {
				subscriber?.receive(completion: .failure(error))
			}
		}
	}
}

extension Publishers.ListenRealm.Inner: Subscription {
	func request(_ demand: Subscribers.Demand) {}
	
	func cancel() {
		worker?.stop()
		subscriber = nil
	}
}

extension Publishers.ListenRealm.Inner: Subscriber {
	func receive(subscription: Subscription) {
		subscription.request(.max(1))
	}
	
	func receive(_ input: Realm.Configuration) -> Subscribers.Demand {
		return .none
	}
	
	func receive(completion: Subscribers.Completion<Error>) {
		Swift.print("Receive completion \(completion)")
		subscriber?.receive(completion: completion)
	}
}
