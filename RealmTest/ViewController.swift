//
//  ViewController.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import UIKit
import Combine

let ID = "3B3267DC-A544-42D4-AC99-74EEE41F4CA8"

class ViewController: UIViewController {
    var subscriptions = Set<AnyCancellable>()
    let userStorage = UserStorage()
    
    override func viewDidLoad() {
        super.viewDidLoad()
//
//        save()
//        get()
//        listenSingle()
//        arbitraryUpdate()
//        deleteByObject()
    }
    
    func save() {
        let user = APIUser(id: UUID().uuidString, name: "api user")

        userStorage.save(user: user)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { result in
                    print(result)
                },
                receiveValue: { _ in }
            )
            .store(in: &subscriptions)
    }
    
    func get() {
        userStorage.getUser(id: ID)
            .receive(on: RunLoop.main)
            .sink { result in
                print(result)
            } receiveValue: { user in
                print(user)
            }
            .store(in: &subscriptions)
    }
    
    func listenSingle() {
        userStorage.listenUser(id: ID)
            .sink(receiveCompletion: { result in
                print("Did end \(result)")
            }, receiveValue: { user in
                print("Updated user: \(user)")
            })
            .store(in: &subscriptions)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.userStorage.getUser(id: ID)
                .compactMap { $0 }
                .map { user in
                    var newUser = user
                    newUser.name = "api test new 1!"
                    return newUser
                }
                .flatMap {
                    self.userStorage.update(user: $0)
                }
                .ignoreOutput()
                .sink { result in
                    print("Did update user \(result)")
                } receiveValue: { _ in }
                .store(in: &self.subscriptions)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.userStorage.getUser(id: ID)
                    .compactMap { $0 }
                    .map { user in
                        var newUser = user
                        newUser.name = "api test new 2!"
                        return newUser
                    }
                    .flatMap {
                        self.userStorage.update(user: $0)
                    }
                    .ignoreOutput()
                    .sink { result in
                        print("Did update user \(result)")
                    } receiveValue: { _ in }
                    .store(in: &self.subscriptions)
            }
        }
    }
    
    func arbitraryUpdate() {
        userStorage.update(id: ID)
            .sink(receiveCompletion: { result in
                print("Did end \(result)")
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
    }
    
    func deleteByObject() {
//        let user = User(id: .init(uuidString: ID)!, name: "fdsf")
        userStorage.delete(id: ID)
            .sink(receiveCompletion: { result in
                print("Did end \(result)")
            }, receiveValue: { _ in })
            .store(in: &subscriptions)
    }
}

