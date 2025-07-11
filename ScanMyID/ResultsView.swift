//

import SwiftUI

struct ResultsView: View {
    let mrzData: String
    let onScanAnother: () -> Void
    @State private var showingSaveSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Scan Results")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                
                // MRZ Data Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Data")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    // Display only the essential MRZ line - full width
                    Text(mrzData)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                        .minimumScaleFactor(0.5) // Auto-scale text to fit smaller screens
                        .allowsTightening(true) // Allow character tightening on small screens
                }
                
                // Parsed Data Section (Day 2)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Parsed Information")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        DataRow(label: "Document Type", value: "To be parsed")
                        DataRow(label: "Country Code", value: "To be parsed")
                        DataRow(label: "Document Number", value: "To be parsed")
                        DataRow(label: "Expiry Date", value: "To be parsed")
                        DataRow(label: "Given Names", value: "To be parsed")
                        DataRow(label: "Surname", value: "To be parsed")
                        DataRow(label: "Nationality", value: "To be parsed")
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // Photo Section (Day 2)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Biometric Photo")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 200)
                        .cornerRadius(8)
                        .overlay(
                            Text("Photo from NFC chip\n(Day 2)")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        )
                }
                .padding(.horizontal, 20)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: saveData) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Data")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        onScanAnother()
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Scan Another ID")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .alert("Data Saved", isPresented: $showingSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your scanned data has been saved locally.")
        }
        .onAppear {
            print("📱 Results screen loaded with MRZ: \(mrzData)")
        }
    }
    
    private func saveData() {
        // TODO: Implement Core Data saving
        print("💾 Saving MRZ data: \(mrzData)")
        showingSaveSuccess = true
    }
    
    private func scanAnother() {
        // TODO: Navigate back to camera - needs parent view coordination
        print("📷 Scan another requested")
    }
    }


struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ResultsView(
        mrzData: "L898902C3UTO7408122F1204159ZE184226B<<<<<10",
        onScanAnother: {}
    )
}
