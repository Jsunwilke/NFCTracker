//
//  AccessibilityNode.swift
//  NFC Sd Tracker
//
//  Created by administrator on 4/26/25.
//


import SwiftUI

/// An extension to add accessibility descriptions to charts
extension View {
    /// Adds accessibility label and value to chart views
    func chartAccessibility<T>(
        label: String,
        summary: String,
        items: [T],
        nameKeyPath: KeyPath<T, String>,
        valueKeyPath: KeyPath<T, String>
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(summary)
            .accessibilityHint("Double tap to access detailed breakdown")
            .overlay(
                VStack {
                    ForEach(0..<items.count, id: \.self) { index in
                        let item = items[index]
                        AccessibilityNode(
                            label: item[keyPath: nameKeyPath],
                            value: item[keyPath: valueKeyPath]
                        )
                    }
                }
                .accessibilityHidden(true)
            )
    }
}

/// Hidden accessibility nodes used to contain data for VoiceOver
struct AccessibilityNode: View {
    let label: String
    let value: String
    
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }
}