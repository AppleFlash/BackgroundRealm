//
//  ListData.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

protocol IdentifierableCellItem {
	static var id: String { get }
	
	var title: String { get }
}

struct ListData<T: IdentifierableCellItem> {
	let header: String?
	let cells: [T]
}


enum ApproachCell: IdentifierableCellItem {
	case old
	case new
	
	static let id: String = "Cell"
	var title: String {
		switch self {
		case .old:
			return "Simple approach for Realm with minimal amount of abstractions"
		case .new:
			return "Proposed approach with Realm incapsulation"
		}
	}
}

enum AppFlowCell: IdentifierableCellItem {
	case swiftUI
	case articleExample
	
	static let id: String = "Cell"
	var title: String {
		switch self {
		case .swiftUI:
			return "I'd like to see SwiftUI example with new Realm approach"
		case .articleExample:
			return "Show me article examples"
		}
	}
}
