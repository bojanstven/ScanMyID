//

import SwiftUI

@main
struct ScanMyIDApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var currentScreen: AppScreen = .welcome
    @State private var scannedMRZ: String = ""
    @State private var passportData: PassportData?
    
    enum AppScreen {
        case welcome
        case camera
        case nfcScan
        case results
    }
    
    var body: some View {
        switch currentScreen {
        case .welcome:
            WelcomeView(onScanTapped: {
                currentScreen = .camera
            })
        case .camera:
            CameraView(onMRZScanned: { mrzData in
                scannedMRZ = mrzData
                print("📱 MRZ Scanned: \(mrzData)")
                // Add haptic feedback and sound
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                currentScreen = .nfcScan
            })
        case .nfcScan:
            NFCView(
                mrzData: scannedMRZ,
                onComplete: { extractedPassportData in
                    passportData = extractedPassportData
                    print("📱 NFC Reading Complete - Moving to results")
                    
                    // Success haptic feedback
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    currentScreen = .results
                }
            )
        case .results:
            if let passportData = passportData {
                ResultsView(
                    passportData: passportData,
                    onScanAnother: {
                        // Reset all data and go back to camera
                        scannedMRZ = ""
                        self.passportData = nil
                        currentScreen = .camera
                    }
                )
            } else {
                // Fallback if no passport data (shouldn't happen)
                Text("No data available")
                    .onAppear {
                        print("❌ No passport data available - returning to welcome")
                        currentScreen = .welcome
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
