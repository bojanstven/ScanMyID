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
                // TODO: Add haptic feedback and chime
                currentScreen = .nfcScan
            })
        case .nfcScan:
            NFCView(mrzData: scannedMRZ, onComplete: {
                currentScreen = .results
            })
        case .results:
            ResultsView(
                mrzData: scannedMRZ,
                onScanAnother: {
                    // Reset and go back to camera
                    scannedMRZ = ""
                    currentScreen = .camera
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
