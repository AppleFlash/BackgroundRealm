//
//  ArticleViewController.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import UIKit

final class ListViewController<T: IdentifierableCellItem>: UIViewController, UITableViewDataSource, UITableViewDelegate {
	private lazy var tableView = UITableView()
	
	private let items: [ListData<T>]
	var selectHandler: ((T) -> Void)?
	
	init(items: [ListData<T>]) {
		self.items = items
		
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = .white
		view.addSubview(tableView)
		tableView.translatesAutoresizingMaskIntoConstraints = false
		tableView.delegate = self
		tableView.dataSource = self
		tableView.estimatedRowHeight = 70
		tableView.rowHeight = UITableView.automaticDimension
		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: T.id)
	}
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return items.count
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return items[section].header
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return items[section].cells.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: T.id, for: indexPath)
		
		let data = items[indexPath.section].cells[indexPath.row]
		cell.textLabel?.text = data.title
		cell.textLabel?.numberOfLines = 0
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		let data = items[indexPath.section].cells[indexPath.row]
		selectHandler?(data)
	}
}
