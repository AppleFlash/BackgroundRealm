//
//  PersistenceChangeset.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 15.06.2021.
//

import RealmSwift

enum PersistenceChangeset<T, Failure: Error> {
    case initial(_ objects: [T])
    case update(deleted: [Int], inserted: [ChangesetItem<T>], modified: [ChangesetItem<T>])
    case error(Failure)
}

extension PersistenceChangeset: Equatable where T: Equatable {
    static func == (lhs: PersistenceChangeset<T, Failure>, rhs: PersistenceChangeset<T, Failure>) -> Bool {
        switch (lhs, rhs) {
        case (let .initial(lhsObj), let .initial(rhsObj)):
            return lhsObj == rhsObj
        case (let .update(lhsDeleted, lhsInserted, lhsModifier), let .update(rhsDeleted, rhsInserted, rhsModifier)):
            return lhsDeleted == rhsDeleted && lhsInserted == rhsInserted && lhsModifier == rhsModifier
        case (let .error(lhsError), let .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
