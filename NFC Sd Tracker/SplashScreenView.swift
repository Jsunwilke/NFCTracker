import SwiftUI
import Firebase

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0.5
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        if isActive {
            // Once active, check if the user is signed in
            if sessionManager.user == nil {
                SignInView().environmentObject(sessionManager)
            } else {
                ContentView().environmentObject(sessionManager)
            }
        } else {
            // Splash screen content
            VStack {
                Image("IconikLogo") // Replace "YourLogo" with your logo asset name.
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.2)) {
                            logoScale = 1.0
                            logoOpacity = 1.0
                        }
                    }
                Text("") // Replace with your app's title.
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .onAppear {
                // Delay for 2 seconds then transition.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isActive = true
                    }
                }
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView().environmentObject(SessionManager())
    }
}

