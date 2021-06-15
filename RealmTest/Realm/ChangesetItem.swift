//
//  ChangesetItem.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 15.06.2021.
//

/// Информация об изменении объекта
struct ChangesetItem<T> {
    /// Индекс в массиве изменённых объектов
    let index: Int
    
    /// Измененный объект
    let item: T
}

extension ChangesetItem: Equatable where T: Equatable {}
