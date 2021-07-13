//
//  Publisher+Diff.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 13.07.2021.
//

import Combine

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
