import SwiftUI

struct WelcomeView: View {
    let onScanTapped: () -> Void
    // Remove onHistoryTapped parameter since we're removing the button
    @State private var animationScale: CGFloat = 1.0
    
    // Computed property to get the app version
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "1.0" // Fallback version if not found
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            // App Title with Version
            VStack(spacing: 30) {
                VStack(spacing: 5) {
                    HStack(spacing: 0) {
                        Text("ScanMy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("ID")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    
                    // Version subtitle
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                // App icon with subtle pulse animation
                HStack(spacing: 10) {
                    Image(systemName: "wave.3.up.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)
                        .scaleEffect(animationScale)
                        .onAppear {
                            withAnimation(
                                Animation.easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                            ) {
                                animationScale = 1.2
                            }
                        }
                }
            }
            
            Spacer()
            
            // Step 1
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 40, height: 40)
                    
                    Text("1")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Text("Scan the machine readable zone on the data page of your passport or the back of your ID")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 15)
            }
            
            // Step 2
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 40, height: 40)
                    
                    Text("2")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Text("Hold your passport or ID against your device to read the biometric chip")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 15)
            }
            
            Spacer()
            
            // Single Action Button (History button removed)
            Button(action: onScanTapped) {
                Text("Scan Document")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    WelcomeView(onScanTapped: {})
}
