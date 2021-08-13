//
//  ListView.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 12.08.2021.
//

import SwiftUI

struct ListView: View {
	@StateObject var viewModel = ViewModel()
	
	var body: some View {
		VStack(spacing: 8) {
			Text("Tap user's name to modify")
			
			HStack {
				Button {
					viewModel.addUser()
				} label: {
					Text("Add user")
				}
				
				Spacer(minLength: 0)
				
				Button {
					viewModel.addUsers()
				} label: {
					Text("Add list of users")
				}
			}.padding(.horizontal, 16)
		}

		List {
			ForEach(viewModel.users) { user in
				VStack(alignment: .leading, spacing: 8) {
					Text("Name: \(user.name)").onTapGesture {
						viewModel.didTap(user: user)
					}
					Text("Role: \(user.role.rawValue)")
					if let modifyCount = user.modifyCount {
						Text("Modify count: \(modifyCount)")
					}
				}
				
			}
			.onDelete { set in
				viewModel.deleteUser(at: set.first!)
			}
		}
	}
}
