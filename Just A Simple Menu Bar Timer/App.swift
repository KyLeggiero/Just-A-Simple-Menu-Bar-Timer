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
    
    @NSApplicationDelegateAdaptor
    private var appDelegate: AppDelegate
    
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Text(Introspection.appName)
                    .bold()
                    .frame(minHeight: 20)
                
                Spacer().fixedSize()
                
                ContentView()
            }
            .ignoresSafeArea()
            .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
    }
}



private extension App {
    class AppDelegate: NSObject, NSApplicationDelegate {
        
        var menuBarIcon: NSStatusItem!
        
        func applicationDidFinishLaunching(_ notification: Notification) {
            menuBarIcon = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            menuBarIcon.button?.image = NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Test")
            
            
            NSApp.windows.forEach { window in
//                print(window)
//
////                window.styleMask = [.resizable]
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        }
    }
}
