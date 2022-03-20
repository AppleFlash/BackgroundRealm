//
//  ExampleController.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 20.03.2022.
//

import UIKit
import Combine

final class ExampleViewContoller: UIViewController {
	private let output: ViewOutput
	
	private lazy var button = UIButton()
	private var subscriptions = Set<AnyCancellable>()
	
	init(output: ViewOutput) {
		self.output = output
		
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = .lightGray
		view.addSubview(button)
		button.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		])
		
		button.backgroundColor = .blue
		button.setTitle("Default title", for: .normal)
		button.addTarget(self, action: #selector(updateName), for: .touchUpInside)
		
		bind()
	}
	
	@objc private func updateName() {
		output.update(name: "Name \(Int.random(in: 1...100))")
	}
	
	private func bind() {
		output
			.user
			.sink { [button] user in
				button.setTitle(user.name, for: .normal)
			}
			.store(in: &subscriptions)
	}
}
