//
//  AccessibleButton.swift
//  NFC Sd Tracker
//
//  Created by administrator on 4/26/25.
//


import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    /// Adds accessibility label and hints to a view
    func accessibilitySupport(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .if(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .if(!traits.isEmpty) { view in
                view.accessibilityAddTraits(traits)
            }
    }
    
    /// Convenience method to add VoiceOver announcement
    func announceForAccessibility(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    /// A conditional modifier
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Add dynamic type support to any view with specific font
    func dynamicTypeSize(_ size: Font) -> some View {
        self
            .font(size)
            .environment(\.sizeCategory, .large)
    }
    
    /// Add a proper semantic button role for accessibility
    func accessibilityButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .if(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Accessible Custom Components

/// A more accessible button with proper contrast and clear tap targets
struct AccessibleButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    let isDestructive: Bool
    let isDisabled: Bool
    
    init(
        title: String,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, 16)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDestructive 
                          ? Color.red 
                          : (isDisabled ? Color.gray : Color.blue))
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .if(isDisabled) { view in
            view.accessibilityHint("Currently unavailable")
        }
    }
}

/// Accessible form field with proper labeling
struct AccessibleFormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let errorMessage: String?
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    
    init(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .keyboardType(keyboardType)
            }
            
            if let error = errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(errorMessage != nil && !errorMessage!.isEmpty ? "Error: \(errorMessage!)" : "")")
        .accessibilityHint(placeholder)
    }
}

/// A more accessible toggle with better labeling
struct AccessibleToggle: View {
    let label: String
    @Binding var isOn: Bool
    let hint: String?
    
    init(label: String, isOn: Binding<Bool>, hint: String? = nil) {
        self.label = label
        self._isOn = isOn
        self.hint = hint
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .foregroundColor(.primary)
                
                if let hint = hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(hint ?? "Double tap to toggle setting")
        .padding(.vertical, 8)
    }
}

/// An accessible image with proper labeling
struct AccessibleImage: View {
    let imageName: String
    let description: String
    let width: CGFloat
    let height: CGFloat
    
    init(imageName: String, description: String, width: CGFloat = 44, height: CGFloat = 44) {
        self.imageName = imageName
        self.description = description
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .accessibilityLabel(description)
            .accessibilityAddTraits(.isImage)
    }
}

/// A system image with proper accessibility
struct AccessibleSystemImage: View {
    let systemName: String
    let description: String
    let font: Font
    let color: Color
    
    init(
        systemName: String,
        description: String,
        font: Font = .body,
        color: Color = .primary
    ) {
        self.systemName = systemName
        self.description = description
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(font)
            .foregroundColor(color)
            .accessibilityLabel(description)
            .accessibilityAddTraits(.isImage)
    }
}

/// Accessibility coordinator to handle special accessibility events
class AccessibilityCoordinator: ObservableObject {
    static let shared = AccessibilityCoordinator()
    
    @Published var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    @Published var isSwitchControlRunning: Bool = UIAccessibility.isSwitchControlRunning
    @Published var isReduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled
    @Published var isReduceTransparencyEnabled: Bool = UIAccessibility.isReduceTransparencyEnabled
    @Published var isDynamicTypeEnabled: Bool = true
    
    private init() {
        // Setup accessibility notification listeners
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusDidChange),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(switchControlStatusDidChange),
            name: UIAccessibility.switchControlStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyStatusDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func voiceOverStatusDidChange() {
        self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    }
    
    @objc private func switchControlStatusDidChange() {
        self.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
    }
    
    @objc private func reduceMotionStatusDidChange() {
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    @objc private func reduceTransparencyStatusDidChange() {
        self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
    }
    
    // Announce a message via VoiceOver
    func announceMessage(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    // Check if the current environment is accessibility-focused
    var isAccessibilityFocused: Bool {
        return isVoiceOverRunning || isSwitchControlRunning
    }
    
    // Preferred animation duration based on accessibility settings
    var preferredAnimationDuration: Double {
        if isReduceMotionEnabled {
            return 0.1 // Almost no animation when reduce motion is enabled
        } else {
            return 0.3 // Standard animation duration
        }
    }
}