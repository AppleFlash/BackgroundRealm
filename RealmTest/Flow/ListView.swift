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
		HStack {
			Button {
				viewModel.addUser()
			} label: {
				Text("Add user")
			}
			
			Button {
				viewModel.addUsers()
			} label: {
				Text("Add list of users")
			}
		}

		List {
			ForEach(viewModel.users) { user in
				Text(user.name).onTapGesture {
					viewModel.didTap(user: user)
				}
			}
			.onDelete { set in
				viewModel.deleteUser(at: set.first!)
			}
		}
	}
}
