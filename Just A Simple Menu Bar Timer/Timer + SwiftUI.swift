//
//  Timer + SwiftUI.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 5/5/22.
//

import Combine
import Foundation
import SwiftUI



private enum TimerUpdater {
    // Empty on-pupose; all members are static
}



private extension TimerUpdater {
    
    /// The publisher wwhich can update all timers' UI
    static let uiUpdatePublisher: AnyPublisher<Void, Never> = {
        Foundation.Timer.publish(every: 0.05, tolerance: 0.05, on: .main, in: .common)
            .autoconnect()
            .map { _ in Void() }
            .eraseToAnyPublisher()
    }()
}



private extension TimerUpdater {
    struct Key: SwiftUI.EnvironmentKey {
        static var defaultValue = TimerUpdater.uiUpdatePublisher
    }
}



public extension EnvironmentValues {
    
    /// A publisher which sends an event every time a timer's UI should be updated
    var timerUpdater: AnyPublisher<Void, Never> {
        get { self[TimerUpdater.Key.self] }
    }
}
