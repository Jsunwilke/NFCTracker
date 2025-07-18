import SwiftUI

/// A TextField with integrated validation and error message display
struct ValidationTextField: View {
    // Text binding from parent
    @Binding var text: String
    
    // TextField properties
    let title: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure: Bool = false
    var autocapitalization: UITextAutocapitalizationType = .sentences
    
    // Validation properties
    var validationRule: (String) -> Bool
    var errorMessage: String
    
    // Internal state
    @State private var isFocused: Bool = false
    @State private var hasBeenEdited: Bool = false
    
    // Computed properties
    private var isValid: Bool {
        validationRule(text)
    }
    
    private var shouldShowError: Bool {
        !isValid && (hasBeenEdited || !isFocused)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            // TextField
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .onChange(of: text) { _ in
                            hasBeenEdited = true
                        }
                        .onAppear {
                            UITextField.appearance().clearButtonMode = .whileEditing
                        }
                } else {
                    TextField(placeholder, text: $text)
                        .onChange(of: text) { _ in
                            hasBeenEdited = true
                        }
                        .onAppear {
                            UITextField.appearance().clearButtonMode = .whileEditing
                        }
                }
            }
            .textContentType(contentType)
            .keyboardType(keyboardType)
            .autocapitalization(autocapitalization)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        shouldShowError ? Color.red : Color.gray,
                        lineWidth: 1
                    )
            )
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .onTapGesture {
                isFocused = true
            }
            
            // Error message
            if shouldShowError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: shouldShowError)
        .onAppear {
            // Set initial focus state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Consider the field edited if it's not empty initially
                if !text.isEmpty {
                    hasBeenEdited = true
                }
            }
        }
    }
}

/// A TextField with integrated picker for validation
struct ValidationPickerField<T: Hashable>: View {
    // Binding from parent
    @Binding var selection: String
    
    // Field properties
    let title: String
    let placeholder: String
    let options: [String]
    var optionValues: [String: T]? = nil
    
    // Validation properties
    var validationRule: (String) -> Bool
    var errorMessage: String
    
    // Internal state
    @State private var isExpanded: Bool = false
    @State private var hasBeenSelected: Bool = false
    
    // Computed properties
    private var isValid: Bool {
        validationRule(selection)
    }
    
    private var shouldShowError: Bool {
        !isValid && hasBeenSelected
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            // Picker Field
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                        hasBeenSelected = true
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? placeholder : selection)
                        .foregroundColor(selection.isEmpty ? Color.gray.opacity(0.8) : Color.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.gray.opacity(0.8))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            shouldShowError ? Color.red : Color.gray,
                            lineWidth: 1
                        )
                )
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
            
            // Error message
            if shouldShowError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: shouldShowError)
        .onAppear {
            // Consider the field selected if it's not empty initially
            if !selection.isEmpty {
                hasBeenSelected = true
            }
        }
    }
}

// Custom toggle with validation
struct ValidationToggle: View {
    @Binding var isOn: Bool
    let title: String
    var errorMessage: String? = nil
    var validationRule: ((Bool) -> Bool)? = nil
    
    private var isValid: Bool {
        guard let rule = validationRule else { return true }
        return rule(isOn)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .foregroundColor(isValid ? .primary : .red)
            }
            .padding(.horizontal)
            
            if let error = errorMessage, !isValid {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 16)
            }
        }
    }
}