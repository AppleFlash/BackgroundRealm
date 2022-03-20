//
//  Publisher+Diff.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 13.07.2021.
//

import Combine

extension Publisher where Output: Collection {
	func diff(comparator: @escaping (Output.Element, Output.Element) -> Bool) -> AnyPublisher<PersistenceChangeset<Output.Element>, Failure> {
		return scan(([Output.Element]?.none, [Output.Element]?.none)) { tuple, array in
			(tuple.1, array.map { $0 })
		}
		.map { old, new in
			guard let oldArray = old else {
				return .initial(new ?? [])
			}
			guard let newArray = new else {
				return .initial([])
			}

			let difference = newArray.difference(from: oldArray, by: comparator)
			return handle(difference: difference)
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
