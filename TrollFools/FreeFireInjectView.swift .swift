//
//  FreeFireInjectView.swift
//  TrollFools
//
//  Auto-inject dylib for Free Fire
//

import CocoaLumberjackSwift
import SwiftUI

struct FreeFireInjectView: View {
    @EnvironmentObject var appList: AppListModel
    
    // The dylib filename in your app bundle
    private let dylibName = "FIle.dylib"
    
    @State private var freeFireApp: App?
    @State private var isInjected = false
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var showError = false
    @State private var lastError: Error?
    
    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool
    @AppStorage var injectStrategy: InjectorV3.Strategy
    
    init() {
        let bid = "com.dts.freefireth"
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(bid)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(bid)")
        _injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(bid)")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App Info Section
            if let app = freeFireApp {
                VStack(spacing: 12) {
                    Image(uiImage: app.icon ?? UIImage())
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(18)
                    
                    Text(app.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(app.bid)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let version = app.version {
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Status Badge
                    HStack(spacing: 6) {
                        Image(systemName: isInjected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isInjected ? .green : .secondary)
                        Text(isInjected ? "Injected" : "Not Injected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Free Fire Not Found")
                        .font(.headline)
                    
                    Text("Make sure Free Fire (com.dts.freefireth) is installed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            
            Spacer()
            
            // Status Message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action Button
            if freeFireApp != nil {
                Button(action: {
                    if isInjected {
                        ejectDylib()
                    } else {
                        injectDylib()
                    }
                }) {
                    HStack(spacing: 12) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: isInjected ? "eject.fill" : "syringe.fill")
                        }
                        
                        Text(isInjected ? "Eject Hack" : "Inject Hack")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isInjected ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .navigationTitle("Free Fire Hack")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFreeFireApp()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(lastError?.localizedDescription ?? "Unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Functions
    
    private func loadFreeFireApp() {
        freeFireApp = appList.apps.first { $0.bid == "com.dts.freefireth" }
        
        if let app = freeFireApp {
            checkInjectionStatus(app)
        }
    }
    
    private func checkInjectionStatus(_ app: App) {
        do {
            let injector = try InjectorV3(app.url)
            let injectedAssets = injector.injectedAssetURLsInBundle(app.url)
            
            // Check if our dylib is already injected
            isInjected = injectedAssets.contains { url in
                url.lastPathComponent == dylibName
            }
            
        } catch {
            DDLogError("Failed to check injection status: \(error)", ddlog: InjectorV3.main.logger)
        }
    }
    
    private func getDylibURL() -> URL? {
        // Try to find the dylib in the app bundle
        if let url = Bundle.main.url(forResource: dylibName.replacingOccurrences(of: ".dylib", with: ""), withExtension: "dylib") {
            return url
        }
        
        // Alternative: Check in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dylibPath = documentsPath.appendingPathComponent(dylibName)
        
        if FileManager.default.fileExists(atPath: dylibPath.path) {
            return dylibPath
        }
        
        return nil
    }
    
    private func injectDylib() {
        guard let app = freeFireApp else { return }
        guard let dylibURL = getDylibURL() else {
            statusMessage = "Dylib file not found in bundle"
            showError = true
            lastError = NSError(domain: "TrollFools", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not find \(dylibName) in app bundle or Documents folder"
            ])
            return
        }
        
        isProcessing = true
        statusMessage = "Injecting..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                
                if injector.appID.isEmpty {
                    injector.appID = app.bid
                }
                
                if injector.teamID.isEmpty {
                    injector.teamID = app.teamID
                }
                
                injector.useWeakReference = useWeakReference
                injector.preferMainExecutable = preferMainExecutable
                injector.injectStrategy = injectStrategy
                
                try injector.inject([dylibURL], shouldPersist: true)
                
                DispatchQueue.main.async {
                    isProcessing = false
                    isInjected = true
                    statusMessage = "Successfully injected!"
                    app.reload()
                    
                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        statusMessage = ""
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    statusMessage = "Injection failed"
                    lastError = error
                    showError = true
                    DDLogError("Injection failed: \(error)", ddlog: InjectorV3.main.logger)
                }
            }
        }
    }
    
    private func ejectDylib() {
        guard let app = freeFireApp else { return }
        
        isProcessing = true
        statusMessage = "Ejecting..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                
                if injector.appID.isEmpty {
                    injector.appID = app.bid
                }
                
                if injector.teamID.isEmpty {
                    injector.teamID = app.teamID
                }
                
                injector.useWeakReference = useWeakReference
                injector.preferMainExecutable = preferMainExecutable
                injector.injectStrategy = injectStrategy
                
                // Find the injected dylib
                let injectedAssets = injector.injectedAssetURLsInBundle(app.url)
                let dylibToEject = injectedAssets.filter { $0.lastPathComponent == dylibName }
                
                if !dylibToEject.isEmpty {
                    try injector.eject(dylibToEject, shouldDesist: true)
                }
                
                DispatchQueue.main.async {
                    isProcessing = false
                    isInjected = false
                    statusMessage = "Successfully ejected!"
                    app.reload()
                    
                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        statusMessage = ""
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    statusMessage = "Ejection failed"
                    lastError = error
                    showError = true
                    DDLogError("Ejection failed: \(error)", ddlog: InjectorV3.main.logger)
                }
            }
        }
    }
}
