//
//  TestNFCView.swift
//  ScanMyID
//
//  Created by Bojan Mijic on 13.07.2025.
//


import SwiftUI
import NFCPassportReader

struct TestNFCView: View {
    var body: some View {
        VStack {
            Text("NFC Test")
            Button("Test Import") {
                // This verifies the library is properly linked
                let reader = PassportReader()
                print("✅ NFCPassportReader loaded: \(reader)")
            }
        }
    }
}