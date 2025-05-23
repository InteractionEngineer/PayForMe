//
//  Combine.swift
//  PayForMe
//
//  Created by Max Tharr on 02.10.20.
//

import Combine
import Foundation

extension Publisher where Failure == Never {
    var asUIPublisher: AnyPublisher<Output, Never> {
        receive(on: RunLoop.main).eraseToAnyPublisher()
    }
}
