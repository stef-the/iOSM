//
//  RegionManager.swift
//  iOSM
//
//  Handles downloading and managing offline map regions
//

import Foundation
import CoreLocation
import SwiftUI
import Combine

// MARK: - Region Models
struct MapRegion: Identifiable, Codable {
    let id = UUID()
    let name: String
    let displayName: String
    let boundingBox: BoundingBox
    let downloadURL: String
    let estimatedSize: Int64 // in bytes
    let version: String
    var isDownloaded: Bool = false
    var downloadDate: Date?
    var localPath: String?
    
    struct BoundingBox: Codable {
        let north: Double
        let south: Double
        let east: Double
        let west: Double
        
        var center: CLLocationCoordinate2D {
            CLLocationCoordinate2D(
                latitude: (north + south) / 2,
                longitude: (east + west) / 2
            )
        }
        
        func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
            return coordinate.latitude >= south &&
                   coordinate.latitude <= north &&
                   coordinate.longitude >= west &&
                   coordinate.longitude <= east
        }
    }
}

enum RegionDownloadState {
    case idle
    case downloading(progress: Double)
    case completed
    case failed(Error)
    case cancelled
}

// MARK: - Region Manager
@MainActor
class RegionManager: ObservableObject {
    @Published var availableRegions: [MapRegion] = []
    @Published var downloadedRegions: [MapRegion] = []
    @Published var downloadStates: [String: RegionDownloadState] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    private let regionsDirectory: URL
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    
    init() {
        // Create regions directory in Documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        regionsDirectory = documentsPath.appendingPathComponent("MapRegions")
        
        createRegionsDirectory()
        loadAvailableRegions()
        loadDownloadedRegions()
    }
    
    // MARK: - Directory Management
    
    private func createRegionsDirectory() {
        do {
            try fileManager.createDirectory(at: regionsDirectory, withIntermediateDirectories: true)
            print("Created regions directory at: \(regionsDirectory.path)")
        } catch {
            print("Failed to create regions directory: \(error)")
        }
    }
    
    private func regionDirectory(for regionName: String) -> URL {
        return regionsDirectory.appendingPathComponent(regionName)
    }
    
    // MARK: - Available Regions Loading
    
    private func loadAvailableRegions() {
        // In a real app, this would fetch from a server
        // For now, we'll use some sample regions
        availableRegions = [
            MapRegion(
                name: "london",
                displayName: "London, UK",
                boundingBox: MapRegion.BoundingBox(
                    north: 51.6723, south: 51.2867,
                    east: 0.3340, west: -0.5103
                ),
                downloadURL: "https://download.geofabrik.de/europe/great-britain/england/greater-london-latest.osm.pbf",
                estimatedSize: 250_000_000, // ~250MB
                version: "2024.08.29"
            ),
            MapRegion(
                name: "yorkshire",
                displayName: "Yorkshire, UK",
                boundingBox: MapRegion.BoundingBox(
                    north: 54.7299, south: 53.3781,
                    east: -0.1636, west: -2.7847
                ),
                downloadURL: "https://download.geofabrik.de/europe/great-britain/england/yorkshire-and-the-humber-latest.osm.pbf",
                estimatedSize: 180_000_000, // ~180MB
                version: "2024.08.29"
            ),
            MapRegion(
                name: "scotland",
                displayName: "Scotland, UK",
                boundingBox: MapRegion.BoundingBox(
                    north: 60.8614, south: 54.6344,
                    east: -0.7276, west: -8.6500
                ),
                downloadURL: "https://download.geofabrik.de/europe/great-britain/scotland-latest.osm.pbf",
                estimatedSize: 450_000_000, // ~450MB
                version: "2024.08.29"
            )
        ]
        print("Loaded \(availableRegions.count) available regions")
    }
    
    // MARK: - Downloaded Regions Management
    
    private func loadDownloadedRegions() {
        downloadedRegions.removeAll()
        
        do {
            let regionDirectories = try fileManager.contentsOfDirectory(at: regionsDirectory, includingPropertiesForKeys: nil)
            
            for regionDir in regionDirectories where regionDir.hasDirectoryPath {
                let regionName = regionDir.lastPathComponent
                
                // Check if region metadata exists
                let metadataPath = regionDir.appendingPathComponent("metadata.json")
                if fileManager.fileExists(atPath: metadataPath.path),
                   let data = try? Data(contentsOf: metadataPath),
                   var region = try? JSONDecoder().decode(MapRegion.self, from: data) {
                    
                    region.isDownloaded = true
                    region.localPath = regionDir.path
                    downloadedRegions.append(region)
                    downloadStates[regionName] = .completed
                }
            }
        } catch {
            print("Failed to load downloaded regions: \(error)")
            errorMessage = "Failed to load downloaded regions"
        }
        
        print("Loaded \(downloadedRegions.count) downloaded regions")
    }
    
    // MARK: - Region Download
    
    func downloadRegion(_ region: MapRegion) {
        let regionName = region.name
        
        // Check if already downloaded
        if downloadedRegions.contains(where: { $0.name == regionName }) {
            errorMessage = "Region '\(region.displayName)' is already downloaded"
            return
        }
        
        // Check if already downloading
        if case .downloading = downloadStates[regionName] {
            return
        }
        
        downloadStates[regionName] = .downloading(progress: 0.0)
        
        // Create region directory
        let regionDir = regionDirectory(for: regionName)
        do {
            try fileManager.createDirectory(at: regionDir, withIntermediateDirectories: true)
        } catch {
            downloadStates[regionName] = .failed(error)
            errorMessage = "Failed to create region directory"
            return
        }
        
        // For demonstration, simulate a download process
        // In a real app, you would download the actual OSM data and process it
        simulateDownload(region: region, to: regionDir)
    }
    
    private func simulateDownload(region: MapRegion, to directory: URL) {
        let regionName = region.name
        
        // Simulate download with progress updates
        Task {
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                try? await Task.sleep(for: .milliseconds(500))
                
                await MainActor.run {
                    downloadStates[regionName] = .downloading(progress: progress)
                }
            }
            
            // Simulate processing time
            try? await Task.sleep(for: .seconds(2))
            
            await MainActor.run {
                // Create sample files to simulate downloaded region
                createSampleRegionFiles(region: region, in: directory)
            }
        }
    }
    
    private func createSampleRegionFiles(region: MapRegion, in directory: URL) {
        let regionName = region.name
        
        do {
            // Create sample map tiles file
            let mapTilesPath = directory.appendingPathComponent("map.mbtiles")
            try "Sample MBTiles data for \(region.displayName)".write(to: mapTilesPath, atomically: true, encoding: .utf8)
            
            // Create sample routing data directory
            let routingDir = directory.appendingPathComponent("routing_tiles")
            try fileManager.createDirectory(at: routingDir, withIntermediateDirectories: true)
            
            // Create sample geocoding database
            let geocodingPath = directory.appendingPathComponent("places.sqlite")
            try "Sample geocoding database for \(region.displayName)".write(to: geocodingPath, atomically: true, encoding: .utf8)
            
            // Save region metadata
            var updatedRegion = region
            updatedRegion.isDownloaded = true
            updatedRegion.downloadDate = Date()
            updatedRegion.localPath = directory.path
            
            let metadataPath = directory.appendingPathComponent("metadata.json")
            let metadataData = try JSONEncoder().encode(updatedRegion)
            try metadataData.write(to: metadataPath)
            
            // Update state
            downloadedRegions.append(updatedRegion)
            downloadStates[regionName] = .completed
            
            print("Successfully 'downloaded' region: \(region.displayName)")
            
        } catch {
            downloadStates[regionName] = .failed(error)
            errorMessage = "Failed to create region files: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Region Deletion
    
    func deleteRegion(_ region: MapRegion) {
        let regionName = region.name
        let regionDir = regionDirectory(for: regionName)
        
        do {
            try fileManager.removeItem(at: regionDir)
            downloadedRegions.removeAll { $0.name == regionName }
            downloadStates.removeValue(forKey: regionName)
            print("Deleted region: \(region.displayName)")
        } catch {
            errorMessage = "Failed to delete region: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Utility Methods
    
    func regionForCoordinate(_ coordinate: CLLocationCoordinate2D) -> MapRegion? {
        return downloadedRegions.first { region in
            region.boundingBox.contains(coordinate)
        }
    }
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func isRegionDownloaded(_ regionName: String) -> Bool {
        return downloadedRegions.contains { $0.name == regionName }
    }
    
    func downloadProgress(for regionName: String) -> Double {
        if case let .downloading(progress) = downloadStates[regionName] {
            return progress
        }
        return 0.0
    }
    
    // MARK: - Cancel Download
    
    func cancelDownload(_ regionName: String) {
        downloadTasks[regionName]?.cancel()
        downloadTasks.removeValue(forKey: regionName)
        downloadStates[regionName] = .cancelled
    }
}
