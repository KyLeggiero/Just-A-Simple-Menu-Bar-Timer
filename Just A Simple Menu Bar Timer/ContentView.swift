//
//  ContentView.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 4/19/22.
//

import SwiftUI

struct ContentView: View {
    
    @State
    var timers: [Timer] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(timers) { timer in
                TimerListItemView(timer: timer)
            }
        }
        .frame(minWidth: 200)
        .padding()
        
        .task {
            timers = [
                await Timer(kind: .countDown(totalTimeToCountDown: 10 * 60)),
                await Timer(kind: .countUp(totalTimeToCountUp: 5 * 60)),
                await Timer(kind: .countDown(totalTimeToCountDown: 30 * 60)),
                await Timer(kind: .countUp(totalTimeToCountUp: 5)),
            ]
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
