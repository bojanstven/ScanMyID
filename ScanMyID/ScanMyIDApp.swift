//

import SwiftUI

@main
struct ScanMyIDApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var scannedMRZ: String = ""
    @State private var passportData: PassportData?
    @State private var scanFlowState: ScanFlowState = .camera
    
    enum ScanFlowState {
        case camera
        case nfc
        case results
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab (Your Welcome Screen)
            WelcomeView(
                onScanTapped: {
                    selectedTab = 1 // Switch to Scan tab
                    scanFlowState = .camera // Reset to camera
                }
            )
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // Scan Tab (Complete Flow: Camera -> NFC -> Results)
            ScanFlowView(
                scannedMRZ: $scannedMRZ,
                passportData: $passportData,
                scanFlowState: $scanFlowState,
                onHome: {
                    selectedTab = 0 // Return to Home
                    resetScanData()
                }
            )
            .tabItem {
                Image(systemName: "camera.fill")
                Text("Scan")
            }
            .tag(1)
            
            // History Tab
            SavedScansView(onDismiss: {
                // For TabView, we don't dismiss, just stay in tab
            })
            .tabItem {
                Image(systemName: "list.clipboard.fill")
                Text("History")
            }
            .tag(2)
        }
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
    
    private func resetScanData() {
        scannedMRZ = ""
        passportData = nil
        scanFlowState = .camera
    }
}

// MARK: - Scan Flow View (Handles Camera -> NFC -> Results)
struct ScanFlowView: View {
    @Binding var scannedMRZ: String
    @Binding var passportData: PassportData?
    @Binding var scanFlowState: ContentView.ScanFlowState
    let onHome: () -> Void
    
    var body: some View {
        switch scanFlowState {
        case .camera:
            CameraView(onMRZScanned: { mrzData in
                scannedMRZ = mrzData
                print("📱 MRZ Scanned: \(mrzData)")
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                scanFlowState = .nfc
            })
            
        case .nfc:
            NFCView(
                mrzData: scannedMRZ,
                onComplete: { extractedPassportData in
                    passportData = extractedPassportData
                    print("📱 NFC Reading Complete - Moving to results")
                    
                    // Success haptic feedback
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    scanFlowState = .results
                }
            )
            
        case .results:
            if let passportData = passportData {
                ResultsView(
                    passportData: passportData,
                    onScanAnother: {
                        // Reset and restart scan flow
                        scannedMRZ = ""
                        self.passportData = nil
                        scanFlowState = .camera
                    },
                    onHome: onHome
                )
            } else {
                // Fallback - shouldn't happen
                VStack {
                    Text("No data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("Return to Camera") {
                        scanFlowState = .camera
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .onAppear {
                    print("❌ No passport data available in results")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
