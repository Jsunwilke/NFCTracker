//
//  DeleteConfirmationAlert.swift
//  NFC Sd Tracker
//
//  Created by administrator on 4/26/25.
//


import SwiftUI

struct DeleteConfirmationAlert: View {
    let item: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Confirm Deletion")
                .font(.headline)
                .padding(.top)
            
            Text("Are you sure you want to delete this \(item)?")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(minWidth: 100)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                
                Button(action: onConfirm) {
                    Text("Delete")
                        .frame(minWidth: 100)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.bottom)
        }
        .frame(width: 300)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

struct AlertConfiguration {
    var title: String
    var message: String
    var primaryButtonTitle: String
    var secondaryButtonTitle: String?
    var isDestructive: Bool
    var primaryAction: () -> Void
    var secondaryAction: (() -> Void)?
}

// Reusable confirmation dialog that works on any action
struct ConfirmationDialogView: View {
    @Binding var isPresented: Bool
    var config: AlertConfiguration
    
    var body: some View {
        ZStack {
            if isPresented {
                // Semi-transparent background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Optionally dismiss on background tap
                        // isPresented = false
                    }
                
                // Alert content
                VStack(spacing: 20) {
                    Text(config.title)
                        .font(.headline)
                        .padding(.top)
                    
                    Text(config.message)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        if let secondaryTitle = config.secondaryButtonTitle, let secondaryAction = config.secondaryAction {
                            Button(action: {
                                isPresented = false
                                secondaryAction()
                            }) {
                                Text(secondaryTitle)
                                    .frame(minWidth: 100)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Button(action: {
                            isPresented = false
                            config.primaryAction()
                        }) {
                            Text(config.primaryButtonTitle)
                                .frame(minWidth: 100)
                                .padding()
                                .background(config.isDestructive ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom)
                }
                .frame(width: 300)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .transition(.scale)
            }
        }
        .animation(.easeInOut, value: isPresented)
    }
}

// Extension to help with presenting custom alerts
extension View {
    func customAlert(isPresented: Binding<Bool>, config: AlertConfiguration) -> some View {
        ZStack {
            self
            ConfirmationDialogView(isPresented: isPresented, config: config)
        }
    }
}