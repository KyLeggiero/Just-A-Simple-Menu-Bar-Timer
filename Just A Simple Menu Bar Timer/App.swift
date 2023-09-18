//
//  App.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 4/19/22.
//

import Introspection
import SwiftUI



@main
struct App: SwiftUI.App {
    
    
    
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading) {
                Text(Introspection.appName)
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .padding()
                    .background(.bar)
                
                Spacer().fixedSize()
                
                ContentView(timers: timers)
            }
        } label: {
            Image(systemName: "circle.hexagongrid.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
