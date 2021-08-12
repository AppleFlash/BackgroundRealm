//
//  Publisher+.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

import Combine

extension Publisher {
	func sink() -> AnyCancellable {
		return sink(receiveCompletion: { _ in }, receiveValue: { _ in })
	}
}
