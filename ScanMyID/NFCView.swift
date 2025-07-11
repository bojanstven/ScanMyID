//

import SwiftUI

struct NFCView: View {
    let mrzData: String
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // NFC Icon
            Image(systemName: "wave.3.right")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Hold your document flat against your device")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Keep the document still while we read the NFC chip")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Temporary button for Day 1 testing
            Button(action: onComplete) {
                Text("Skip to Results (Day 1 Test)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .onAppear {
            print("📱 Ready for NFC with MRZ data: \(mrzData)")
            // TODO Day 2: Initialize NFC session here
        }
    }
}

#Preview {
    NFCView(mrzData: "P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<<<<", onComplete: {})
}
