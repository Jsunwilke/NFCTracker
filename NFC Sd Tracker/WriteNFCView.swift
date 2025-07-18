import SwiftUI
import CoreNFC

struct WriteNFCView: View {
    @StateObject var nfcWriter = NFCWriterCoordinator()
    @State private var cardNumber: String = ""
    @State private var suggestedCardNumber: String = ""
    @State private var suggestedBoxNumber: String = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isJobBox = false
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 43/255, green: 62/255, blue: 80/255)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Write to NFC Tag")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    // Toggle between SD Card and Job Box
                    Picker("Item Type", selection: $isJobBox) {
                        Text("SD Card").tag(false)
                        Text("Job Box").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: isJobBox) { _ in
                        // Clear the card number when switching types
                        cardNumber = ""
                        fetchSuggestedNumber()
                    }
                    
                    TextField(isJobBox ? "Enter Job Box Number (3001+)" : "Enter SD Card Number (1001-2000)", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.2) : Color.white)
                        .cornerRadius(8)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: 300)
                    
                    // Show appropriate suggestion based on type
                    if !suggestedCardNumber.isEmpty && !isJobBox {
                        Text("Suggested SD Card Number: \(suggestedCardNumber)")
                            .foregroundColor(.white)
                    } else if !suggestedBoxNumber.isEmpty && isJobBox {
                        Text("Suggested Job Box Number: \(suggestedBoxNumber)")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: validateAndWriteNFC) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Write NFC")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Write NFC")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onChange(of: nfcWriter.isWritingSuccessful) { success in
                if success {
                    saveRecordAfterWriting()
                }
            }
            .onChange(of: nfcWriter.errorMessage) { error in
                if let errorMessage = error {
                    alertMessage = errorMessage
                    showAlert = true
                }
            }
            .onAppear {
                fetchSuggestedNumber()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK"), action: {
                          if alertMessage == "Record saved successfully." {
                              dismiss()
                          }
                      }))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func validateAndWriteNFC() {
        // Validate number is in the correct range based on type
        if isJobBox {
            guard let number = Int(cardNumber), number >= 3001 else {
                alertMessage = "Please enter a valid job box number (3001 or greater)."
                showAlert = true
                return
            }
        } else {
            guard let number = Int(cardNumber), number >= 1001, number <= 2000 else {
                alertMessage = "Please enter a valid SD card number (between 1001-2000)."
                showAlert = true
                return
            }
        }
        
        writeNFC()
    }
    
    func writeNFC() {
        let languageCode = "en"
        guard let langData = languageCode.data(using: .utf8),
              let textData = cardNumber.data(using: .utf8) else {
            alertMessage = "Unable to create NDEF payload."
            showAlert = true
            return
        }
        
        let statusByte = UInt8(langData.count)
        var payloadBytes = Data([statusByte])
        payloadBytes.append(langData)
        payloadBytes.append(textData)
        
        guard let typeData = "T".data(using: .utf8) else {
            alertMessage = "Unable to create type data."
            showAlert = true
            return
        }
        
        let ndefPayload = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: typeData,
            identifier: Data(),
            payload: payloadBytes
        )
        
        let message = NFCNDEFMessage(records: [ndefPayload])
        nfcWriter.beginWriting(with: message)
    }
    
    func saveRecordAfterWriting() {
        isSaving = true
        let timestamp = Date()
        guard let orgID = sessionManager.user?.organizationID else {
            alertMessage = "User organization not found."
            showAlert = true
            return
        }
        
        if isJobBox {
            // Save Job Box record
            FirestoreManager.shared.saveJobBoxRecord(
                timestamp: timestamp,
                photographer: "",
                boxNumber: cardNumber,
                school: "",
                status: "Packed",
                organizationID: orgID,
                userId: sessionManager.user?.id ?? ""
            ) { result in
                isSaving = false
                switch result {
                case .success:
                    alertMessage = "Job box record saved successfully."
                case .failure(let error):
                    alertMessage = "Failed to save job box record: \(error.localizedDescription)"
                }
                showAlert = true
            }
        } else {
            // Save SD Card record
            FirestoreManager.shared.saveRecord(
                timestamp: timestamp,
                photographer: "",
                cardNumber: cardNumber,
                school: "",
                status: "Cleared",
                uploadedFromJasonsHouse: "",
                uploadedFromAndysHouse: "",
                organizationID: orgID,
                userId: sessionManager.user?.id ?? ""
            ) { result in
                isSaving = false
                switch result {
                case .success:
                    alertMessage = "SD card record saved successfully."
                case .failure(let error):
                    alertMessage = "Failed to save SD card record: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    
    func fetchSuggestedNumber() {
        guard let orgID = sessionManager.user?.organizationID else { return }
        
        if isJobBox {
            // Fetch highest job box number
            FirestoreManager.shared.getHighestBoxNumber(organizationID: orgID) { result in
                switch result {
                case .success(let highestNumber):
                    DispatchQueue.main.async {
                        self.suggestedBoxNumber = String(highestNumber + 1)
                        if self.cardNumber.isEmpty {
                            self.cardNumber = String(highestNumber + 1)
                        }
                    }
                case .failure(let error):
                    print("Error fetching highest box number:", error.localizedDescription)
                    // If error, default to 3001
                    DispatchQueue.main.async {
                        self.suggestedBoxNumber = "3001"
                        if self.cardNumber.isEmpty {
                            self.cardNumber = "3001"
                        }
                    }
                }
            }
        } else {
            // Fetch highest SD card number
            FirestoreManager.shared.fetchRecords(field: "all", value: "", organizationID: orgID) { result in
                switch result {
                case .success(let records):
                    let numbers = records.compactMap { Int($0.cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if let maxNumber = numbers.max() {
                        let suggestion = maxNumber + 1
                        // Ensure suggestion stays in range 1001-2000
                        let validSuggestion = max(1001, min(2000, suggestion))
                        DispatchQueue.main.async {
                            self.suggestedCardNumber = String(validSuggestion)
                            if self.cardNumber.isEmpty {
                                self.cardNumber = String(validSuggestion)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.suggestedCardNumber = "1001"
                            if self.cardNumber.isEmpty {
                                self.cardNumber = "1001"
                            }
                        }
                    }
                case .failure(let error):
                    print("Error fetching records for suggestion:", error.localizedDescription)
                    // If error, default to 1001
                    DispatchQueue.main.async {
                        self.suggestedCardNumber = "1001"
                        if self.cardNumber.isEmpty {
                            self.cardNumber = "1001"
                        }
                    }
                }
            }
        }
    }
}

struct WriteNFCView_Previews: PreviewProvider {
    static var previews: some View {
        WriteNFCView().environmentObject(SessionManager())
    }
}
