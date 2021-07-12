//
//  Publisher+Diff.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 13.07.2021.
//

import Combine

//extension Publisher where Output: Collection, Output.Element: Equatable {
//	func diff() -> AnyPublisher<PersistenceChangeset<Output.Element>, Failure> {
//		return scan((Output?, Output)?.none) { old, new  in
//			return (old?.1, new)
//		}
//		.compactMap { $0 }
//		.map { old, new in
//			if let previous = old, !previous.isEmpty {
//				let difference = Array(new).difference(from: Array(previous))
//				return handle(difference: difference)
//			} else {
//				return .initial(Array(new))
//			}
//		}
//		.eraseToAnyPublisher()
//	}
//}
//
extension Publisher where Output: Collection {
	func diff(comparator: @escaping (Output.Element, Output.Element) -> Bool) -> AnyPublisher<PersistenceChangeset<Output.Element>, Failure> {
		return scan(([Output.Element](), [Output.Element]())) { old, new  in
			return (old.1, new.map { $0 })
		}
		.compactMap { $0 }
		.map { old, new in
			if !old.isEmpty {
				let difference = new.difference(from: old, by: comparator)
				return handle(difference: difference)
			} else {
				return .initial(new)
			}
		}
		.eraseToAnyPublisher()
	}
}

private func handle<T>(difference: CollectionDifference<T>) -> PersistenceChangeset<T> {
	var inserted: [ChangesetItem<T>] = []
	var removed: [Int] = []
	difference.forEach { change in
		switch change {
		case let .insert(offset, element, _):
			inserted.append(ChangesetItem(index: offset, item: element))
		case let .remove(offset, _, _):
			removed.append(offset)
		}
	}

	return .update(deleted: removed, inserted: inserted)
}
//
//extension Publisher where Output: Collection, Output.Element: Equatable {
//	func diff() -> Publishers.Diff<Self> {
//		return .init(upstream: self)
//	}
//}

//extension Publishers {
//	struct Diff<Upstream: Publisher>: Publisher where Upstream.Output: Collection, Upstream.Output.Element: Equatable {
//		typealias Failure = Upstream.Failure
//		typealias Output = PersistenceChangeset<Upstream.Output.Element>
//
//		private let upstream: Upstream
//
//		init(upstream: Upstream) {
//			self.upstream = upstream
//		}
//
//		func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
//			let sub = DiffSubscriber(subscriber: subscriber)
//			upstream.receive(subscriber: sub)
//		}
//	}
//}
//
//extension Publishers.Diff {
//	final class DiffSubscriber<S: Subscriber>: Subscriber where S.Input == Output, S.Failure == Failure {
//		typealias Input = Upstream.Output
//		typealias Failure = Upstream.Failure
//
//		private var previous: Input?
//		private let subscriber: S
//
//		init(subscriber: S) {
//			self.subscriber = subscriber
//		}
//
//		func receive(subscription: Subscription) {
//			subscription.request(.unlimited)
//		}
//
//		func receive(_ input: Upstream.Output) -> Subscribers.Demand {
//			let changes: PersistenceChangeset<Input.Element>
//			if let previous = previous {
//				let difference = Array(input).difference(from: Array(previous))
//				changes = handle(difference: difference)
//			} else {
//				changes = .initial(input.map { $0 })
//			}
//			previous = input
//
//			return subscriber.receive(changes)
//		}
//
//		func receive(completion: Subscribers.Completion<Upstream.Failure>) {
//			subscriber.receive(completion: completion)
//		}
//	}
//}
//
//extension Publisher where Output: Collection {
//	func diff(comparator: @escaping Publishers.NotEquitableDiff<Self>.Comparator) -> Publishers.NotEquitableDiff<Self> {
//		return .init(upstream: self, comparator: comparator)
//	}
//}
//
//extension Publishers {
//	struct NotEquitableDiff<Upstream: Publisher>: Publisher where Upstream.Output: Collection {
//		typealias Failure = Upstream.Failure
//		typealias Output = PersistenceChangeset<Upstream.Output.Element>
//		typealias Comparator = (Upstream.Output.Element, Upstream.Output.Element) -> Bool
//
//		private let upstream: Upstream
//		private let comparator: Comparator
//
//		init(upstream: Upstream, comparator: @escaping Comparator) {
//			self.upstream = upstream
//			self.comparator = comparator
//		}
//
//		func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
//			let sub = NotEquitableDiffSubscriber(subscriber: subscriber, comparator: comparator)
//			upstream.receive(subscriber: sub)
//		}
//	}
//}
//
//extension Publishers.NotEquitableDiff {
//	final class NotEquitableDiffSubscriber<S: Subscriber>: Subscriber where S.Input == Output, S.Failure == Failure {
//		typealias Input = Upstream.Output
//		typealias Failure = Upstream.Failure
//
//		private var previous: [Input.Element] = [] {
//			didSet {
//				Swift.print("\n\n ====")
//				Swift.print(previous)
//				Swift.print("\n\n ====")
//			}
//		}
//		private let subscriber: S
//		private let comparator: Comparator
//
//		init(subscriber: S, comparator: @escaping Comparator) {
//			self.subscriber = subscriber
//			self.comparator = comparator
//		}
//
//		func receive(subscription: Subscription) {
//			subscription.request(.unlimited)
//		}
//
//		func receive(_ input: Upstream.Output) -> Subscribers.Demand {
//			let changes: PersistenceChangeset<Input.Element>
//			Swift.print("BGIN \(input.map { $0 })")
//			Swift.print("BGIN \(self) \n")
//			Swift.print("BGIN \(previous.map { $0 })")
//			Swift.print("---->")
//			if !previous.isEmpty {
//				Swift.print("=========")
//				Swift.print("input: \(input.map { $0 })")
//				Swift.print("previous: \(previous.map { $0 })")
//				let difference = Array(input).difference(from: previous, by: comparator)
//				Swift.print("difference: \(difference)")
//				changes = handle(difference: difference)
//			} else {
//				changes = .initial(input.map { $0 })
//			}
//			previous = Array(input)
//			Swift.print("BGIN \(previous.map { $0 })")
//			Swift.print("<----")
//
//			return subscriber.receive(changes)
//		}
//
//		func receive(completion: Subscribers.Completion<Upstream.Failure>) {
//			subscriber.receive(completion: completion)
//		}
//	}
//}
