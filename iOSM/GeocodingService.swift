//
//  GeocodingService.swift
//  iOSM
//
//  Offline geocoding and search functionality using SQLite FTS5
//

import Foundation
import CoreLocation
import SQLite3
import SwiftUI

// MARK: - Place Models
struct Place: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: PlaceType
    let coordinate: CLLocationCoordinate2D
    let importance: Double // Ranking score 0.0-1.0
    let address: String?
    let adminArea: String? // City, county, etc.
    
    enum PlaceType: String, CaseIterable {
        case poi = "poi"           // Point of interest
        case street = "street"     // Street/road
        case city = "city"         // City/town
        case village = "village"   // Village
        case suburb = "suburb"     // Suburb/neighborhood
        case building = "building" // Building/address
        
        var displayName: String {
            switch self {
            case .poi: return "POI"
            case .street: return "Street"
            case .city: return "City"
            case .village: return "Village"
            case .suburb: return "Suburb"
            case .building: return "Building"
            }
        }
        
        var icon: String {
            switch self {
            case .poi: return "mappin.circle"
            case .street: return "road.lanes"
            case .city: return "building.2.crop.circle"
            case .village: return "house.circle"
            case .suburb: return "house.lodge.circle"
            case .building: return "building.circle"
            }
        }
    }
}

// MARK: - Geocoding Service
@MainActor
class GeocodingService: ObservableObject {
    @Published var searchResults: [Place] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "geocoding.database", qos: .userInitiated)
    private let maxResults = 50
    
    init() {
        Task {
            await initializeDatabase()
            await populateSampleData()
        }
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Management
    
    private func initializeDatabase() async {
        await withCheckedContinuation { continuation in
            dbQueue.async {
                self.setupDatabase()
                continuation.resume()
            }
        }
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent("geocoding.sqlite").path
        
        // Open database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database at: \(dbPath)")
            return
        }
        
        // Create FTS5 table for full-text search
        let createTableSQL = """
        CREATE VIRTUAL TABLE IF NOT EXISTS places USING fts5(
            name,
            type,
            lat,
            lon,
            importance,
            address,
            admin_area,
            tokens
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("Error creating table: \(errmsg)")
        }
        
        print("Geocoding database initialized successfully")
    }
    
    private func closeDatabase() {
        sqlite3_close(db)
    }
    
    // MARK: - Sample Data Population
    
    private func populateSampleData() async {
        await withCheckedContinuation { continuation in
            dbQueue.async {
                self.insertSamplePlaces()
                continuation.resume()
            }
        }
    }
    
    private func insertSamplePlaces() {
        // Check if data already exists
        let countSQL = "SELECT COUNT(*) FROM places"
        var countStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, countSQL, -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                let count = sqlite3_column_int(countStmt, 0)
                if count > 0 {
                    sqlite3_finalize(countStmt)
                    print("Geocoding database already has \(count) places")
                    return
                }
            }
        }
        sqlite3_finalize(countStmt)
        
        // Sample places around UK (focusing on areas near Barnard Castle)
        let samplePlaces = [
            // Cities and towns
            ("London", "city", 51.5074, -0.1278, 1.0, "Greater London, England", "Greater London"),
            ("Edinburgh", "city", 55.9533, -3.1883, 0.9, "Scotland", "Edinburgh"),
            ("Manchester", "city", 53.4808, -2.2426, 0.8, "Greater Manchester, England", "Greater Manchester"),
            ("Birmingham", "city", 52.4862, -1.8904, 0.8, "West Midlands, England", "West Midlands"),
            ("Leeds", "city", 53.8008, -1.5491, 0.7, "West Yorkshire, England", "West Yorkshire"),
            ("Newcastle upon Tyne", "city", 54.9783, -1.6178, 0.7, "Tyne and Wear, England", "Tyne and Wear"),
            ("Durham", "city", 54.7761, -1.5733, 0.6, "County Durham, England", "County Durham"),
            ("Barnard Castle", "city", 54.6454, -1.8463, 0.5, "County Durham, England", "County Durham"),
            ("Darlington", "city", 54.5253, -1.5541, 0.5, "County Durham, England", "County Durham"),
            ("Richmond", "city", 54.4028, -1.7406, 0.4, "North Yorkshire, England", "North Yorkshire"),
            
            // POIs around Barnard Castle area
            ("Bowes Museum", "poi", 54.6450, -1.8456, 0.6, "Newgate, Barnard Castle", "County Durham"),
            ("Raby Castle", "poi", 54.6372, -1.8738, 0.5, "Staindrop, Darlington", "County Durham"),
            ("High Force Waterfall", "poi", 54.6456, -2.1261, 0.7, "Forest-in-Teesdale", "County Durham"),
            ("Bowlees Visitor Centre", "poi", 54.6395, -2.1089, 0.4, "Forest-in-Teesdale", "County Durham"),
            ("Eggleston Hall", "poi", 54.6089, -1.9367, 0.3, "Eggleston, Barnard Castle", "County Durham"),
            ("Startforth", "village", 54.6506, -1.8592, 0.3, "Near Barnard Castle", "County Durham"),
            ("Cotherstone", "village", 54.6275, -1.9089, 0.3, "Near Barnard Castle", "County Durham"),
            
            // Streets in Barnard Castle
            ("Market Place", "street", 54.6456, -1.8467, 0.4, "Barnard Castle town center", "County Durham"),
            ("The Bank", "street", 54.6453, -1.8459, 0.3, "Barnard Castle", "County Durham"),
            ("Galgate", "street", 54.6461, -1.8471, 0.3, "Barnard Castle", "County Durham"),
            ("Newgate", "street", 54.6449, -1.8453, 0.3, "Barnard Castle", "County Durham"),
            
            // More POIs
            ("Tower Bridge", "poi", 51.5055, -0.0754, 0.8, "Tower Hamlets, London", "Greater London"),
            ("Buckingham Palace", "poi", 51.5014, -0.1419, 0.9, "Westminster, London", "Greater London"),
            ("Edinburgh Castle", "poi", 55.9486, -3.1999, 0.9, "Edinburgh", "Edinburgh"),
            ("Stonehenge", "poi", 51.1789, -1.8262, 0.9, "Wiltshire, England", "Wiltshire"),
            ("York Minster", "poi", 53.9619, -1.0818, 0.8, "York, England", "North Yorkshire"),
            ("Durham Cathedral", "poi", 54.7732, -1.5755, 0.8, "Durham", "County Durham"),
            ("Hadrian's Wall", "poi", 55.0246, -2.3314, 0.8, "Northumberland, England", "Northumberland"),
            
            // Universities
            ("Durham University", "poi", 54.7692, -1.5750, 0.6, "Durham", "County Durham"),
            ("Newcastle University", "poi", 54.9805, -1.6134, 0.6, "Newcastle upon Tyne", "Tyne and Wear"),
            ("University of Leeds", "poi", 53.8067, -1.5551, 0.6, "Leeds", "West Yorkshire")
        ]
        
        let insertSQL = """
        INSERT INTO places (name, type, lat, lon, importance, address, admin_area, tokens) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            for place in samplePlaces {
                let tokens = generateSearchTokens(name: place.0, type: place.1, adminArea: place.6)
                
                sqlite3_bind_text(stmt, 1, place.0, -1, nil)              // name
                sqlite3_bind_text(stmt, 2, place.1, -1, nil)              // type
                sqlite3_bind_double(stmt, 3, place.2)                     // lat
                sqlite3_bind_double(stmt, 4, place.3)                     // lon
                sqlite3_bind_double(stmt, 5, place.4)                     // importance
                sqlite3_bind_text(stmt, 6, place.5, -1, nil)              // address
                sqlite3_bind_text(stmt, 7, place.6, -1, nil)              // admin_area
                sqlite3_bind_text(stmt, 8, tokens, -1, nil)               // tokens
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    print("Error inserting place \(place.0): \(errmsg)")
                }
                
                sqlite3_reset(stmt)
            }
        }
        
        sqlite3_finalize(stmt)
        print("Inserted \(samplePlaces.count) sample places into geocoding database")
    }
    
    private func generateSearchTokens(name: String, type: String, adminArea: String) -> String {
        var tokens = [name.lowercased()]
        
        // Add individual words
        tokens.append(contentsOf: name.lowercased().components(separatedBy: CharacterSet.whitespaces))
        
        // Add type
        tokens.append(type.lowercased())
        
        // Add admin area words
        tokens.append(contentsOf: adminArea.lowercased().components(separatedBy: CharacterSet.whitespaces))
        
        return tokens.joined(separator: " ")
    }
    
    // MARK: - Search Methods
    
    func search(_ query: String) async {
        await MainActor.run {
            isSearching = true
            errorMessage = nil
        }
        
        let results = await performSearch(query)
        
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
    }
    
    private func performSearch(_ query: String) async -> [Place] {
        return await withCheckedContinuation { continuation in
            dbQueue.async {
                let results = self.executeSearch(query)
                continuation.resume(returning: results)
            }
        }
    }
    
    private func executeSearch(_ query: String) -> [Place] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let searchQuery = query.trimmingCharacters(in: .whitespaces)
        let searchSQL = """
        SELECT name, type, lat, lon, importance, address, admin_area, 
               rank 
        FROM places 
        WHERE places MATCH ? 
        ORDER BY importance DESC, rank 
        LIMIT ?
        """
        
        var stmt: OpaquePointer?
        var results: [Place] = []
        
        if sqlite3_prepare_v2(db, searchSQL, -1, &stmt, nil) == SQLITE_OK {
            // Create FTS5 query - add wildcard for partial matches
            let ftsQuery = "\(searchQuery)*"
            sqlite3_bind_text(stmt, 1, ftsQuery, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(maxResults))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                let typeString = String(cString: sqlite3_column_text(stmt, 1))
                let lat = sqlite3_column_double(stmt, 2)
                let lon = sqlite3_column_double(stmt, 3)
                let importance = sqlite3_column_double(stmt, 4)
                
                let address = sqlite3_column_text(stmt, 5) != nil ?
                    String(cString: sqlite3_column_text(stmt, 5)) : nil
                let adminArea = sqlite3_column_text(stmt, 6) != nil ?
                    String(cString: sqlite3_column_text(stmt, 6)) : nil
                
                let type = Place.PlaceType(rawValue: typeString) ?? .poi
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                
                let place = Place(
                    name: name,
                    type: type,
                    coordinate: coordinate,
                    importance: importance,
                    address: address,
                    adminArea: adminArea
                )
                
                results.append(place)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("Error preparing search query: \(errmsg)")
        }
        
        sqlite3_finalize(stmt)
        return results
    }
    
    // MARK: - Reverse Geocoding
    
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D, radius: Double = 1000) async -> [Place] {
        return await withCheckedContinuation { continuation in
            dbQueue.async {
                let results = self.executeReverseGeocode(coordinate, radius: radius)
                continuation.resume(returning: results)
            }
        }
    }
    
    private func executeReverseGeocode(_ coordinate: CLLocationCoordinate2D, radius: Double) -> [Place] {
        // Simple bounding box search (in a real implementation, you'd use proper geographic distance)
        let latDelta = radius / 111320.0 // Approximate meters per degree latitude
        let lonDelta = radius / (111320.0 * cos(coordinate.latitude * .pi / 180.0))
        
        let searchSQL = """
        SELECT name, type, lat, lon, importance, address, admin_area 
        FROM places 
        WHERE lat BETWEEN ? AND ? 
          AND lon BETWEEN ? AND ?
        ORDER BY importance DESC 
        LIMIT ?
        """
        
        var stmt: OpaquePointer?
        var results: [Place] = []
        
        if sqlite3_prepare_v2(db, searchSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, coordinate.latitude - latDelta)   // min lat
            sqlite3_bind_double(stmt, 2, coordinate.latitude + latDelta)   // max lat
            sqlite3_bind_double(stmt, 3, coordinate.longitude - lonDelta)  // min lon
            sqlite3_bind_double(stmt, 4, coordinate.longitude + lonDelta)  // max lon
            sqlite3_bind_int(stmt, 5, 10) // Limit to 10 results for reverse geocoding
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                let typeString = String(cString: sqlite3_column_text(stmt, 1))
                let lat = sqlite3_column_double(stmt, 2)
                let lon = sqlite3_column_double(stmt, 3)
                let importance = sqlite3_column_double(stmt, 4)
                
                let address = sqlite3_column_text(stmt, 5) != nil ?
                    String(cString: sqlite3_column_text(stmt, 5)) : nil
                let adminArea = sqlite3_column_text(stmt, 6) != nil ?
                    String(cString: sqlite3_column_text(stmt, 6)) : nil
                
                let type = Place.PlaceType(rawValue: typeString) ?? .poi
                let placeCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                
                let place = Place(
                    name: name,
                    type: type,
                    coordinate: placeCoordinate,
                    importance: importance,
                    address: address,
                    adminArea: adminArea
                )
                
                results.append(place)
            }
        }
        
        sqlite3_finalize(stmt)
        return results
    }
    
    // MARK: - Utility Methods
    
    func clearResults() {
        searchResults = []
    }
    
    func getSuggestions(for query: String) async -> [String] {
        guard query.count >= 2 else { return [] }
        
        return await withCheckedContinuation { continuation in
            dbQueue.async {
                let suggestions = self.executeSuggestions(query)
                continuation.resume(returning: suggestions)
            }
        }
    }
    
    private func executeSuggestions(_ query: String) -> [String] {
        let searchSQL = """
        SELECT DISTINCT name 
        FROM places 
        WHERE name LIKE ? 
        ORDER BY importance DESC 
        LIMIT 5
        """
        
        var stmt: OpaquePointer?
        var suggestions: [String] = []
        
        if sqlite3_prepare_v2(db, searchSQL, -1, &stmt, nil) == SQLITE_OK {
            let pattern = "\(query)%"
            sqlite3_bind_text(stmt, 1, pattern, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                suggestions.append(name)
            }
        }
        
        sqlite3_finalize(stmt)
        return suggestions
    }
}
