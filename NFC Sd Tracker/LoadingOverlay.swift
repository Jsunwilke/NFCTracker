//
//  LoadingOverlay.swift
//  NFC Sd Tracker
//
//  Created by administrator on 4/26/25.
//


import SwiftUI

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            // Loading indicator with message
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(30)
            .background(Color(UIColor.darkGray).opacity(0.8))
            .cornerRadius(15)
            .shadow(radius: 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading: \(message)")
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
        .zIndex(100) // Ensure it's on top of everything
    }
}

// View extension to make it easy to show loading overlay
extension View {
    func loadingOverlay(isPresented: Binding<Bool>, message: String) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                LoadingOverlay(message: message)
                    .animation(.easeInOut, value: isPresented.wrappedValue)
            }
        }
    }
}

// Toast notification for operation results
struct ToastView: View {
    let message: String
    let isSuccess: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack(spacing: 15) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSuccess ? .green : .red)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(isSuccess ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
            .cornerRadius(10)
            .shadow(radius: 5)
        }
        .padding(.horizontal)
        .padding(.top, 5)
        .transition(.move(edge: .top))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isSuccess ? "Success" : "Error"): \(message)")
    }
}

// View extension to show toast notifications
extension View {
    func toast(isPresented: Binding<Bool>, message: String, isSuccess: Bool = true) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                VStack {
                    ToastView(message: message, isSuccess: isSuccess) {
                        isPresented.wrappedValue = false
                    }
                    
                    Spacer()
                }
                .animation(.easeInOut, value: isPresented.wrappedValue)
                .onAppear {
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isPresented.wrappedValue = false
                    }
                }
                .zIndex(99)
            }
        }
    }
}