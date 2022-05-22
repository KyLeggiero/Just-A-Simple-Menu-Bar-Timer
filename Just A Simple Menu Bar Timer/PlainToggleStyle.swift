//
//  PlainToggleStyle.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 5/21/22.
//

import SwiftUI



/// A completely undecorated toggle; just its label
public struct PlainToggleStyle: ToggleStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
        
            .onTapGesture {
                configuration.isOn.toggle()
            }
    }
}



public extension ToggleStyle where Self == PlainToggleStyle {
    /// A completely undecorated toggle; just its label
    static var plain: Self { Self() }
}
