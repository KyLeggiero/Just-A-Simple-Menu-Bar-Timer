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
    private var currentTimeDisplayValue = ""
    
    @State
    private var toggleTitle: LocalizedStringKey = ""
    
    @ObservedObject
    private(set) var timer: Timer
    
    var body: some View {
        HStack {
            Toggle(isOn: $timer.isRunning, label: { TimerToggleLabel(timer.currentValue) })
                .onReceive(timer.stateChangePublisher) { timerValue in
                    toggleTitle = timerValue.toggleTitle
                }
                .toggleStyle(.plain)
            
            VStack(alignment: .leading) {
                Text("Unnamed Timer")
                    .font(.caption)
                
                Text(currentTimeDisplayValue)
                    .font(.largeTitle)
            }
            
            Spacer()
        }
        
        .onReceive(timerUpdater) {
            currentTimeDisplayValue = timer.currentValue.description
        }
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
        case .notStarted(startingValue: let value),
                .running(currentValue: let value),
                .completed(finalValue: let value),
                .paused(currentValue: let value):
            return format(value)
        }
    }
    
    
    private static let timeFormatter: DateComponentsFormatter = {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = [.hour, .minute, .second]
        return timeFormatter
    }()
    
    
    private func format(_ timestamp: TimeInterval) -> String {
        Self.timeFormatter.string(from: timestamp)
            ?? "\(Int(timestamp.rounded())) seconds"
    }
}



struct TimerListItemView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            TimerListItemView(timer: Timer(kind: .countDown(totalTimeToCountDown: 10)))
            TimerListItemView(timer: Timer(kind: .countDown(totalTimeToCountDown: 1000)))
        }
    }
}
