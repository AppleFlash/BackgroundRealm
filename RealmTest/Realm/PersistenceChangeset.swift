//
//  PersistenceChangeset.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 15.06.2021.
//

import RealmSwift

enum PersistenceChangeset<T> {
	case initial(_ objects: [T])
	case update(deleted: [Int], inserted: [ChangesetItem<T>])
}

extension PersistenceChangeset: Equatable where T: Equatable {
	static func == (lhs: PersistenceChangeset<T>, rhs: PersistenceChangeset<T>) -> Bool {
		switch (lhs, rhs) {
		case (let .initial(lhsObj), let .initial(rhsObj)):
			return lhsObj == rhsObj
		case (let .update(lhsDeleted, lhsInserted), let .update(rhsDeleted, rhsInserted)):
			return lhsDeleted == rhsDeleted && lhsInserted == rhsInserted
		default:
			return false
		}
	}
}

extension PersistenceChangeset {
	func apply(to array: inout [T]) {
		switch self {
		case let .initial(users):
			array = users
		case let .update(deleted, inserted):
			deleted.forEach { array.remove(at: $0) }
			inserted.forEach { array.insert($0.item, at: $0.index) }
		}
	}
}
