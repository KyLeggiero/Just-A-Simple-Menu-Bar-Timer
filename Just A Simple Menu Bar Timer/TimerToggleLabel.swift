//
//  TimerToggleLabel.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 5/21/22.
//

import Combine
import SwiftUI



/// The style used for toggles which control timers
public struct TimerToggleLabel: View {
    
    private let label: LocalizedStringKey
    
    
    public init(_ value: Timer.Value) {
        switch value {
        case .notStarted(startingValue: _),
                .paused(currentValue: _):
            label = "▶️"
            
        case .running(currentValue: _):
            label = "⏸"
            
        case .completed(finalValue: _):
            label = "✅"
        }
    }
    
    
    public var body: some View {
        Text(label)
            .font(.system(size: 48))
    }
}



struct TimerToggleStyle_Previews: PreviewProvider {
    static var previews: some View {
        Toggle(isOn: .constant(false)) {
            TimerToggleLabel(.notStarted(startingValue: 10))
        }
        .toggleStyle(.plain)
    }
}
