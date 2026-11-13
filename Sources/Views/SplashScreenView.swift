import SwiftUI
import AppKit

// MARK: - Animated Modern Startup / Splash Loading Screen

public struct SplashScreenView: View {
    @State private var isPulsing = false
    @State private var progress: CGFloat = 0.0
    
    public var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Vector App Emblem
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.35), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(isPulsing ? 1.08 : 0.94)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                    
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 6) {
                    Text("Quillfolio")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("Digital Ink & Geometry Studio")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Sleek Loader Bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 180, height: 4)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 180 * progress, height: 4)
                }
                .padding(.top, 12)
            }
        }
        .onAppear {
            isPulsing = true
            withAnimation(.easeInOut(duration: 0.9)) {
                progress = 1.0
            }
        }
    }
}
