//
//  RegionsView.swift
//  iOSM
//
//  UI for managing offline map regions
//

import SwiftUI
import CoreLocation

struct RegionsView: View {
    @StateObject private var regionManager = RegionManager()
    @StateObject private var locationService = LocationService()
    @State private var selectedTab = 0
    @State private var showingDeleteAlert = false
    @State private var regionToDelete: MapRegion?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Regions", selection: $selectedTab) {
                    Text("Available").tag(0)
                    Text("Downloaded").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                if selectedTab == 0 {
                    availableRegionsView
                } else {
                    downloadedRegionsView
                }
                
                // Error message if any
                if let error = regionManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                regionManager.errorMessage = nil
                            }
                        }
                }
            }
            .navigationTitle("Offline Maps")
            .navigationBarItems(trailing: refreshButton)
        }
        .onAppear {
            locationService.requestLocation()
        }
        .alert("Delete Region", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let region = regionToDelete {
                    regionManager.deleteRegion(region)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let region = regionToDelete {
                Text("Are you sure you want to delete '\(region.displayName)'? This will remove all offline map data for this region.")
            }
        }
    }
    
    // MARK: - Available Regions View
    
    private var availableRegionsView: some View {
        List {
            if regionManager.availableRegions.isEmpty {
                Text("No regions available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(regionManager.availableRegions) { region in
                    AvailableRegionRow(
                        region: region,
                        regionManager: regionManager,
                        currentLocation: locationService.location
                    )
                }
            }
        }
        .refreshable {
            // In a real app, this would refresh the available regions list
            print("Refreshing available regions...")
        }
    }
    
    // MARK: - Downloaded Regions View
    
    private var downloadedRegionsView: some View {
        List {
            if regionManager.downloadedRegions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No offline maps")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Download regions from the Available tab to use maps offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            } else {
                ForEach(regionManager.downloadedRegions) { region in
                    DownloadedRegionRow(region: region) {
                        regionToDelete = region
                        showingDeleteAlert = true
                    }
                }
            }
            
            // Storage summary
            if !regionManager.downloadedRegions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    
                    Text("Storage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    
                    let totalSize = regionManager.downloadedRegions.reduce(0) { $0 + $1.estimatedSize }
                    Text("Total: \(regionManager.formatFileSize(totalSize))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(regionManager.downloadedRegions.count) region(s)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
        }
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button("Refresh") {
            locationService.requestLocation()
        }
        .font(.caption)
    }
}

// MARK: - Available Region Row
struct AvailableRegionRow: View {
    let region: MapRegion
    let regionManager: RegionManager
    let currentLocation: CLLocation?
    
    private var downloadState: RegionDownloadState {
        regionManager.downloadStates[region.name] ?? .idle
    }
    
    private var isInRegion: Bool {
        guard let location = currentLocation else { return false }
        return region.boundingBox.contains(location.coordinate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(region.displayName)
                        .font(.headline)
                    
                    Text("Size: \(regionManager.formatFileSize(region.estimatedSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Version: \(region.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Location indicator
                if isInRegion {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                
                // Download button or progress
                downloadButton
            }
            
            // Download progress bar
            if case let .downloading(progress) = downloadState {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var downloadButton: some View {
        switch downloadState {
        case .idle:
            if regionManager.isRegionDownloaded(region.name) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Download") {
                    regionManager.downloadRegion(region)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
        case .downloading:
            Button("Cancel") {
                regionManager.cancelDownload(region.name)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
        case .failed(let error):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.caption)
                Button("Retry") {
                    regionManager.downloadRegion(region)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
        case .cancelled:
            Button("Download") {
                regionManager.downloadRegion(region)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Downloaded Region Row
struct DownloadedRegionRow: View {
    let region: MapRegion
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(region.displayName)
                        .font(.headline)
                    
                    if let downloadDate = region.downloadDate {
                        Text("Downloaded: \(downloadDate, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Size: \(regionManager.formatFileSize(region.estimatedSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            
            // Region coverage info
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("Ready for offline use")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Preview
#Preview {
    RegionsView()
}
