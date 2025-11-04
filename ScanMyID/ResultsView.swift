import SwiftUI
import CoreData

struct ResultsView: View {
    let passportData: PassportData
    let onScanAnother: () -> Void
    let onHome: () -> Void
    @State private var showingSaveSuccess = false
    @State private var showingSavedScans = false
    @State private var isPhotoFullScreen = false
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with Auth Overlay on Photo
                HStack {
                    VStack(alignment: .leading) {
                        Text("Scan Results")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: passportData.isAuthenticated ? "checkmark.shield.fill" : "exclamationmark.shield")
                                .foregroundColor(passportData.isAuthenticated ? .green : .orange)
                            Text(passportData.isAuthenticated ? "Authenticated" : "Read Only")
                                .font(.caption)
                                .foregroundColor(passportData.isAuthenticated ? .green : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Photo section with authentication overlay - right aligned to screen edge
                    ZStack(alignment: .bottomLeading) {
                        if let photo = passportData.photo {
                            Button(action: { isPhotoFullScreen = true }) {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            }
                            
                            // Authentication overlay - lower left corner
                            CryptoAuthOverlay(passportData: passportData)
                                .offset(x: 4, y: -4)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    VStack {
                                        Image(systemName: "person.crop.rectangle")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                        Text("No Photo")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Always show Expiry Banner for any status - UPDATED ICONS
                let expiryDateString = passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate
                if let expiryDate = parseExpiryDate(expiryDateString) {
                    let status = checkPassportValidity(expiryDate: expiryDate)
                    HStack {
                        // UPDATED: Professional icons instead of emoji
                        Image(systemName: status == .expired ? "xmark.circle.fill" : status == .expiresSoon ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(status.color)
                        
                        VStack(alignment: .leading) {
                            Text(status == .expired ? "Passport Expired" : status == .expiresSoon ? "Passport Expires Soon" : "Passport Valid")
                                .font(.headline)
                                .foregroundColor(status.color)
                            
                            Text(ExpiryFormatter.formatTimeRemaining(from: expiryDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(status.color.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                
                // Personal Information
                if let personalDetails = passportData.personalDetails {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            DataRow(label: "Full Name", value: personalDetails.fullName)
                            DataRow(label: "Given Names", value: personalDetails.givenNames)
                            DataRow(label: "Surname", value: personalDetails.surname)
                            DataRow(label: "Nationality", value: personalDetails.nationality)
                            DataRow(label: "Date of Birth", value: personalDetails.dateOfBirth)
                            DataRow(label: "Sex", value: personalDetails.sex)
                            
                            if let placeOfBirth = personalDetails.placeOfBirth {
                                DataRow(label: "Place of Birth", value: placeOfBirth)
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Document Information with Country Flag
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Information")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        DataRow(label: "Document Type", value: passportData.personalDetails?.documentType ?? passportData.mrzData.documentType ?? "Unknown")
                        DataRow(label: "Document Number", value: passportData.personalDetails?.documentNumber ?? passportData.mrzData.documentNumber)
                        DataRow(label: "Issuing Country", value: CountryFlags.flagWithCode(passportData.personalDetails?.issuingCountry ?? passportData.mrzData.issuingCountry ?? "Unknown"))
                        
                        // Enhanced Expiry Date Row with new formatting
                        EnhancedExpiryDateRow(
                            expiryDateString: passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate
                        )
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // Additional Information (if available)
                if !passportData.additionalInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            ForEach(Array(passportData.additionalInfo.keys.sorted()), id: \.self) { key in
                                DataRow(label: key, value: passportData.additionalInfo[key] ?? "")
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Security Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Security & Verification")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        SecurityRow(label: "BAC Authentication", success: passportData.bacSuccess)
                        SecurityRow(label: "Chip Authentication", success: passportData.chipAuthSuccess)
                        SecurityRow(label: "Digital Signature", success: passportData.isAuthenticated)
                        DataRow(label: "Reading Date", value: DateFormatter.ddMMyyyy.string(from: passportData.readingDate))
                        
                        if !passportData.readingErrors.isEmpty {
                            ForEach(passportData.readingErrors.prefix(3), id: \.self) { error in
                                DataRow(label: "Error", value: error)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // MRZ Data (Technical)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Technical Data")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("MRZ")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(passportData.mrzData.rawMRZ)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                }
                .padding(.horizontal, 20)
                
                // Action Buttons - ONLY Save and Scan Another (Full Width)
                VStack(spacing: 16) {
                    // Save Button (Top)
                    Button(action: saveData) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.document")
                            }
                            Text(isSaving ? "Saving..." : "Save")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isSaving ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    
                    // Scan Another Button (Bottom)
                    Button(action: onScanAnother) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Scan Another")
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 30) // spacing above bubble tab bar
                }

                
                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $isPhotoFullScreen) {
            if let photo = passportData.photo {
                PhotoFullScreenView(photo: photo)
            }
        }
        .sheet(isPresented: $showingSavedScans) {
            SavedScansView(onDismiss: {
                showingSavedScans = false
            })
        }
        .alert("Data Saved", isPresented: $showingSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your passport data has been saved locally and securely.")
        }
        .onAppear {
            print("📱 Results screen loaded with passport data")
            print("👤 Name: \(passportData.personalDetails?.fullName ?? "Unknown")")
            print("🏳️ Nationality: \(passportData.personalDetails?.nationality ?? "Unknown")")
            print("📸 Photo: \(passportData.hasPhoto ? "Yes" : "No")")
            print("🔐 Authenticated: \(passportData.isAuthenticated ? "Yes" : "No")")
        }
    }
    
    private func saveData() {
        isSaving = true
        
        Task {
            let success = await CoreDataManager.shared.savePassport(passportData)
            
            await MainActor.run {
                isSaving = false
                
                if success {
                    showingSaveSuccess = true
                    
                    // Haptic feedback
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                } else {
                    // Handle error - could show error alert
                    print("❌ Failed to save passport data")
                }
            }
        }
    }
}

// MARK: - Crypto Authentication Overlay Component

struct CryptoAuthOverlay: View {
    let passportData: PassportData
    
    private var authStatus: CryptoAuthStatus {
        return determineCryptoAuthStatus(passportData: passportData)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(authStatus.color)
                .frame(width: 20, height: 20)
            
            Image(systemName: authStatus.icon)
                .font(.system(size: 10))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
    }
}

// MARK: - Enhanced Expiry Date Row with New Formatting and UPDATED ICONS

struct EnhancedExpiryDateRow: View {
    let expiryDateString: String
    
    private var validityStatus: PassportValidityStatus {
        guard let expiryDate = parseExpiryDate(expiryDateString) else {
            return .expired // If we can't parse, assume expired
        }
        return checkPassportValidity(expiryDate: expiryDate)
    }
    
    private var timeRemainingText: String {
        guard let expiryDate = parseExpiryDate(expiryDateString) else {
            return "Invalid Date"
        }
        return ExpiryFormatter.formatTimeRemaining(from: expiryDate)
    }
    
    var body: some View {
        VStack(spacing: 1) {
            // Main expiry date row - UPDATED ICON
            HStack {
                Text("Expiry Date")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 4) {
                    // UPDATED: Professional square icons instead of emoji
                    Image(systemName: validityStatus == .expired ? "xmark.square.fill" : validityStatus == .expiresSoon ? "exclamationmark.triangle.fill" : "checkmark.square.fill")
                        .font(.body)
                        .foregroundColor(validityStatus.color)
                    
                    Text(expiryDateString)
                        .fontWeight(.medium)
                        .foregroundColor(validityStatus.color)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Enhanced validity status row with new time formatting
            HStack {
                Text("Validity Status")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(validityStatus.description)
                            .fontWeight(.medium)
                            .foregroundColor(validityStatus.color)
                    }
                    
                    Text(timeRemainingText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

// Keep the original ExpiryDateRow for backward compatibility
struct ExpiryDateRow: View {
    let expiryDateString: String
    
    private var validityStatus: PassportValidityStatus {
        guard let expiryDate = parseExpiryDate(expiryDateString) else {
            return .expired // If we can't parse, assume expired
        }
        return checkPassportValidity(expiryDate: expiryDate)
    }
    
    private var daysRemaining: Int? {
        guard let expiryDate = parseExpiryDate(expiryDateString) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day
    }
    
    var body: some View {
        VStack(spacing: 1) {
            // Main expiry date row
            HStack {
                Text("Expiry Date")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text(validityStatus.icon)
                    Text(expiryDateString)
                        .fontWeight(.medium)
                        .foregroundColor(validityStatus.color)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Validity status row
            HStack {
                Text("Validity Status")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text(validityStatus.description)
                        .fontWeight(.medium)
                        .foregroundColor(validityStatus.color)
                    
                    if let days = daysRemaining, days > 0 {
                        Text("(\(days) days)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
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
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct SecurityRow: View {
    let label: String
    let success: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Image(systemName: success ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .foregroundColor(success ? .green : .red)
                Text(success ? "Verified" : "Failed")
                    .fontWeight(.medium)
                    .foregroundColor(success ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct PhotoFullScreenView: View {
    let photo: UIImage
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background based on color scheme
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 8) // Minimal horizontal padding
                    .padding(.vertical, 0)   // No vertical padding for edge-to-edge
            }
            .navigationTitle("Biometric Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .blue)
                }
            }
        }
    }
}

// MARK: - Enhanced SavedScansView with Fixed Clear Button and Expiry Focus

struct SavedScansView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SavedPassport.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \SavedPassport.pinnedDate, ascending: false),
            NSSortDescriptor(keyPath: \SavedPassport.scanDate, ascending: false)
        ],
        animation: .none  // ← NO animation, instant like Notes
    ) private var savedPassports: FetchedResults<SavedPassport>
    
    var sortedPassports: [SavedPassport] {
        let pinned = savedPassports.filter { $0.isPinned }
            .sorted { ($0.pinnedDate ?? Date.distantPast) > ($1.pinnedDate ?? Date.distantPast) }
        
        let unpinned = savedPassports.filter { !$0.isPinned }
            .sorted { ($0.scanDate ?? Date.distantPast) > ($1.scanDate ?? Date.distantPast) }
        
        return pinned + unpinned
    }
    
    let onDismiss: () -> Void
    @State private var selectedPassportID: NSManagedObjectID?
    @State private var showingFullResults = false
    @State private var isClearing = false
    @State private var contextInitialized = false
    @State private var showingClearConfirmation = false
    
    
    var body: some View {
        NavigationView {
            List {
                if savedPassports.isEmpty {
                    VStack {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No saved scans")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Your saved passport scans will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    let pinnedItems = sortedPassports.filter { $0.isPinned }
                    let unpinnedItems = sortedPassports.filter { !$0.isPinned }
                    
                    // Pinned Section
                    if !pinnedItems.isEmpty {
                        Section(header: Text("PINNED").font(.caption).foregroundColor(.secondary)) {
                            ForEach(pinnedItems, id: \.objectID) { passport in
                                EnhancedSavedPassportRow(passport: passport)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handlePassportTap(passport)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            togglePin(for: passport)
                                        } label: {
                                            Label("Unpin", systemImage: "pin.slash.fill")
                                        }
                                        .tint(.orange)
                                    }
                            }
                            .onDelete { offsets in
                                deletePinnedPassports(at: offsets, from: pinnedItems)
                            }
                        }
                    }
                    
                    // Unpinned Section
                    if !unpinnedItems.isEmpty {
                        Section(header: Text("SCANS").font(.caption).foregroundColor(.secondary)) {
                            ForEach(unpinnedItems, id: \.objectID) { passport in
                                EnhancedSavedPassportRow(passport: passport)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handlePassportTap(passport)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            togglePin(for: passport)
                                        } label: {
                                            Label("Pin", systemImage: "pin.fill")
                                        }
                                        .tint(.orange)
                                    }
                            }
                            .onDelete { offsets in
                                deleteUnpinnedPassports(at: offsets, from: unpinnedItems)
                            }
                        }
                    }
                }
            }

            .navigationTitle("Saved Scans (\(savedPassports.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isClearing ? "Clearing..." : "Clear All") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(isClearing || savedPassports.isEmpty)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        .sheet(isPresented: $showingFullResults) {
            if let selectedPassportID = selectedPassportID {
                FixedPassportResultsView(
                    passportObjectID: selectedPassportID,
                    onDismiss: {
                        showingFullResults = false
                        self.selectedPassportID = nil
                    }
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .onAppear {
            initializeContext()
        }
        .confirmationDialog(
            "Delete All Scan History?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All (\(savedPassports.count) scans)", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All saved passport scans will be permanently deleted!")
        }
    }
    
    private func initializeContext() {
        guard !contextInitialized && !savedPassports.isEmpty else { return }
        
        print("🔄 Initializing Core Data context...")
        
        for passport in savedPassports {
            _ = passport.fullName
            _ = passport.personalDetailsJSON
            _ = passport.additionalInfoJSON
            _ = passport.photo?.imageData
            viewContext.refresh(passport, mergeChanges: false)
        }
        
        contextInitialized = true
        print("✅ Context initialized for \(savedPassports.count) passports")
    }
    
    private func handlePassportTap(_ passport: SavedPassport) {
        print("👆 Passport tapped: \(passport.fullName ?? "Unknown")")
        
        if !contextInitialized {
            initializeContext()
        }
        
        viewContext.refresh(passport, mergeChanges: false)
        selectedPassportID = passport.objectID
        showingFullResults = true
    }
    
    private func deletePinnedPassports(at offsets: IndexSet, from pinnedItems: [SavedPassport]) {
        let passportsToDelete = offsets.map { pinnedItems[$0] }
        
        for passport in passportsToDelete {
            Task {
                await CoreDataManager.shared.deletePassport(passport)
            }
        }
    }

    private func deleteUnpinnedPassports(at offsets: IndexSet, from unpinnedItems: [SavedPassport]) {
        let passportsToDelete = offsets.map { unpinnedItems[$0] }
        
        for passport in passportsToDelete {
            Task {
                await CoreDataManager.shared.deletePassport(passport)
            }
        }
    }
    
    private func clearAllData() {
        isClearing = true
        Task {
            await CoreDataManager.shared.clearAllData()
            await MainActor.run {
                isClearing = false
                contextInitialized = false
            }
        }
    }
    
    private func togglePin(for passport: SavedPassport) {
        if passport.isPinned {
            // Unpinning - clear pinnedDate to restore original position
            passport.isPinned = false
            passport.pinnedDate = nil
        } else {
            // Pinning - set pinnedDate to NOW (newest pins at top)
            passport.isPinned = true
            passport.pinnedDate = Date()
        }
        
        do {
            try viewContext.save()
            
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
            print("📌 Passport \(passport.isPinned ? "pinned" : "unpinned"): \(passport.fullName ?? "Unknown")")
        } catch {
            print("❌ Failed to toggle pin: \(error)")
        }
    }
}



// MARK: - Enhanced Saved Passport Row with Expiry Focus and UPDATED ICONS

struct EnhancedSavedPassportRow: View {
    let passport: SavedPassport
    @State private var photo: UIImage?
    
    private var validityStatus: PassportValidityStatus {
        guard let expiryDateString = passport.expiryDate,
              let expiryDate = parseExpiryDate(expiryDateString) else {
            return .expired
        }
        return checkPassportValidity(expiryDate: expiryDate)
    }
    
    private var timeRemainingText: String {
        guard let expiryDateString = passport.expiryDate,
              let expiryDate = parseExpiryDate(expiryDateString) else {
            return "Invalid"
        }
        return ExpiryFormatter.formatTimeRemainingCompact(from: expiryDate)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Photo (keep as-is, no ZStack needed)
            if let photo = photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 54)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 54)
                    .cornerRadius(4)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
            
            // Text content (unchanged)
            VStack(alignment: .leading, spacing: 2) {
                Text(passport.fullName ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(CountryFlags.flagWithCode(passport.nationality ?? "Unknown"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Doc: \(passport.documentNumber ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Right side (unchanged)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: validityStatus == .expired ? "xmark.square.fill" : validityStatus == .expiresSoon ? "exclamationmark.triangle.fill" : "checkmark.square.fill")
                        .font(.title3)
                        .foregroundColor(validityStatus.color)
                    
                    Text(validityStatus.description)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(validityStatus.color)
                }
                
                Text(timeRemainingText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .task {
            if let passportId = passport.id {
                photo = await CoreDataManager.shared.loadPhoto(for: passportId)
            }
        }
    }
}

struct FixedPassportResultsView: View {
    let passportObjectID: NSManagedObjectID
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var passportData: PassportData?
    @State private var scanDate: Date = Date()
    @State private var isLoading = true
    @State private var loadingFailed = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView("Loading passport data...")
                            .progressViewStyle(CircularProgressViewStyle())
                        
                        Text("Loading from secure storage...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .navigationTitle("Loading...")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                onDismiss()
                            }
                        }
                    }
                } else if loadingFailed {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Failed to Load Data")
                            .font(.headline)
                        
                        Text("Unable to load passport data from storage.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            loadPassportData()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .navigationTitle("Error")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                onDismiss()
                            }
                        }
                    }
                } else if let passportData = passportData {
                    SavedPassportResultsView(
                        passportData: passportData,
                        scanDate: scanDate,
                        onDismiss: onDismiss
                    )
                }
            }
        }
        .onAppear {
            loadPassportData()
        }
    }
    
    private func loadPassportData() {
        isLoading = true
        loadingFailed = false
        
        Task {
            do {
                let freshPassport = try viewContext.existingObject(with: passportObjectID) as? SavedPassport
                
                guard let passport = freshPassport else {
                    print("❌ Could not get passport object")
                    await MainActor.run {
                        loadingFailed = true
                        isLoading = false
                    }
                    return
                }
                
                // Force all relationships to load
                _ = passport.fullName
                _ = passport.personalDetailsJSON
                _ = passport.additionalInfoJSON
                _ = passport.photo?.imageData
                
                viewContext.refresh(passport, mergeChanges: false)
                
                let reconstructedData = passport.completePassportData
                let passportScanDate = passport.scanDate ?? Date()
                
                await MainActor.run {
                    if let data = reconstructedData {
                        self.passportData = data
                        self.scanDate = passportScanDate
                        self.isLoading = false
                        print("✅ Passport data loaded: \(passport.fullName ?? "Unknown")")
                    } else {
                        print("❌ Data reconstruction failed")
                        self.loadingFailed = true
                        self.isLoading = false
                    }
                }
                
            } catch {
                print("❌ Error loading passport: \(error)")
                await MainActor.run {
                    self.loadingFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}

struct SavedPassportResultsView: View {
    let passportData: PassportData
    let scanDate: Date
    let onDismiss: () -> Void
    @State private var isPhotoFullScreen = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header - right-aligned photo with auth overlay
                HStack {
                    VStack(alignment: .leading) {
                        Text("Saved Scan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: passportData.isAuthenticated ? "checkmark.shield.fill" : "exclamationmark.shield")
                                .foregroundColor(passportData.isAuthenticated ? .green : .orange)
                            Text(passportData.isAuthenticated ? "Authenticated" : "Read Only")
                                .font(.caption)
                                .foregroundColor(passportData.isAuthenticated ? .green : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Photo section with auth overlay - right aligned to screen edge
                    ZStack(alignment: .bottomLeading) {
                        if let photo = passportData.photo {
                            Button(action: { isPhotoFullScreen = true }) {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            }
                            
                            // Authentication overlay - lower left corner
                            CryptoAuthOverlay(passportData: passportData)
                                .offset(x: 4, y: -4)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    VStack {
                                        Image(systemName: "person.crop.rectangle")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                        Text("No Photo")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                
                // Always show Expiry Banner for any status - UPDATED ICONS
                let expiryDateString = passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate
                if let expiryDate = parseExpiryDate(expiryDateString) {
                    let status = checkPassportValidity(expiryDate: expiryDate)
                    HStack {
                        // UPDATED: Professional icons instead of emoji
                        Image(systemName: status == .expired ? "xmark.square.fill" : status == .expiresSoon ? "exclamationmark.triangle.fill" : "checkmark.square.fill")
                            .font(.title2)
                            .foregroundColor(status.color)
                        
                        VStack(alignment: .leading) {
                            Text(status == .expired ? "Passport Expired" : status == .expiresSoon ? "Passport Expires Soon" : "Passport Valid")
                                .font(.headline)
                                .foregroundColor(status.color)
                            
                            Text(ExpiryFormatter.formatTimeRemaining(from: expiryDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(status.color.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                
                // Personal Information
                if let personalDetails = passportData.personalDetails {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            DataRow(label: "Full Name", value: personalDetails.fullName)
                            DataRow(label: "Given Names", value: personalDetails.givenNames)
                            DataRow(label: "Surname", value: personalDetails.surname)
                            DataRow(label: "Nationality", value: personalDetails.nationality)
                            DataRow(label: "Date of Birth", value: personalDetails.dateOfBirth)
                            DataRow(label: "Sex", value: personalDetails.sex)
                            
                            if let placeOfBirth = personalDetails.placeOfBirth {
                                DataRow(label: "Place of Birth", value: placeOfBirth)
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Document Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Information")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        DataRow(label: "Document Type", value: passportData.personalDetails?.documentType ?? passportData.mrzData.documentType ?? "Unknown")
                        DataRow(label: "Document Number", value: passportData.personalDetails?.documentNumber ?? passportData.mrzData.documentNumber)
                        DataRow(label: "Issuing Country", value: CountryFlags.flagWithCode(passportData.personalDetails?.issuingCountry ?? passportData.mrzData.issuingCountry ?? "Unknown"))
                        
                        EnhancedExpiryDateRow(
                            expiryDateString: passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate
                        )
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // Additional Information (if available)
                if !passportData.additionalInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            ForEach(Array(passportData.additionalInfo.keys.sorted()), id: \.self) { key in
                                DataRow(label: key, value: passportData.additionalInfo[key] ?? "")
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Security Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Security & Verification")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        SecurityRow(label: "BAC Authentication", success: passportData.bacSuccess)
                        SecurityRow(label: "Chip Authentication", success: passportData.chipAuthSuccess)
                        SecurityRow(label: "Digital Signature", success: passportData.isAuthenticated)
                        DataRow(label: "Original Scan Date", value: DateFormatter.ddMMyyyy.string(from: scanDate))
                        
                        if !passportData.readingErrors.isEmpty {
                            ForEach(passportData.readingErrors.prefix(3), id: \.self) { error in
                                DataRow(label: "Error", value: error)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // MRZ Data (Technical)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Technical Data")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("MRZ")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(passportData.mrzData.rawMRZ)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $isPhotoFullScreen) {
            if let photo = passportData.photo {
                PhotoFullScreenView(photo: photo)
            }
        }
    }
}

#Preview {
    ResultsView(
        passportData: PassportData(
            mrzData: MRZData(
                documentNumber: "123456789",
                dateOfBirth: "900101",
                expiryDate: "300101",
                rawMRZ: "P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10",
                documentType: "P",
                issuingCountry: "UTO",
                nationality: "UTO",
                sex: "F"
            ),
            personalDetails: PersonalDetails(
                fullName: "Anna Maria Eriksson",
                surname: "Eriksson",
                givenNames: "Anna Maria",
                nationality: "UTO",
                dateOfBirth: "01/01/1990",
                placeOfBirth: nil,
                sex: "F",
                documentNumber: "L898902C3",
                documentType: "P",
                issuingCountry: "UTO",
                expiryDate: "01/01/2030"
            ),
            photo: nil,
            additionalInfo: [:],
            chipAuthSuccess: true,
            bacSuccess: true,
            readingErrors: []
        ),
        onScanAnother: {},
        onHome: {}
    )
}
