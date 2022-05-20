//
//  TimerListItemView.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 4/20/22.
//

import SwiftUI



struct TimerListItemView: View {
    
    @Environment(\.timerUpdater)
    private var timerUpdater
    
    @State
    private var displayValue = ""
    
    @State
    private var toggleTitle: LocalizedStringKey = ""
    
    @ObservedObject
    private(set) var timer: Timer
    
    var body: some View {
        HStack {
            Text(displayValue)
            
            Toggle(toggleTitle, isOn: $timer.isRunning)
                .onReceive(timer.valuePublisher) { timerValue in
                    toggleTitle = timerValue.toggleTitle
                }
        }
            .onReceive(timerUpdater) {
                displayValue = timer.currentValue.description
            }
            .padding().padding()
    }
}



private extension Timer.Value {
    var toggleTitle: LocalizedStringKey {
        switch self {
        case .notStarted(startingValue: _): return "Start"
        case .running(currentValue: _): return "Pause"
        case .paused(currentValue: _): return "Resume"
        case .completed(finalValue: _): return "Restart"
        }
    }
}



extension Timer {
    
    @MainActor
    var isRunning: Bool {
        get {
            switch currentValue {
            case .notStarted(startingValue: _),
                    .paused(currentValue: _),
                    .completed(finalValue: _):
                return false
                
            case .running(currentValue: _):
                return true
            }
        }
        
        set {
            switch currentValue {
            case .notStarted(startingValue: _),
                    .paused(currentValue: _),
                    .completed(finalValue: _):
                Task {
                    await self.start()
                }
                
            case .running(currentValue: _):
                Task {
                    await self.pause()
                }
            }
        }
    }
}



extension Timer.Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notStarted(startingValue: let startingValue):
            return Int(startingValue.rounded()).description
            
        case .running(currentValue: let currentValue):
            return Int(currentValue.rounded()).description
            
        case .completed(finalValue: let finalValue):
            return Int(finalValue.rounded()).description
            
        case .paused(currentValue: let currentValue):
            return Int(currentValue.rounded()).description
        }
    }
}
