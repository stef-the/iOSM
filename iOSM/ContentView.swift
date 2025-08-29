//
//  ContentView.swift
//  iOSM
//
//  Created by stef on 8/29/25.
//

import SwiftUI
import CoreData

// MARK: - Main Content View
// This is the root view of the app. It uses a TabView to switch between different sections.
struct ContentView: View {
    var body: some View {
        TabView {
            // First Tab: Map View
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            // Second Tab: Location Info View
            LocationInfoView()
                .tabItem {
                    Label("Location", systemImage: "location")
                }
            
            // Third Tab: Settings View
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Location Info View
// This view shows detailed information about the device's current location.
struct LocationInfoView: View {
    // The LocationService handles CoreLocation logic (authorization, coordinates, etc.)
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title
                Text("Location Details")
                    .font(.largeTitle)
                    .padding()
                
                // MARK: Location Status Display
                VStack(spacing: 10) {
                    if let location = locationService.location {
                        // If location is successfully fetched, display location details
                        VStack {
                            Text("📍 Current Location")
                                .font(.headline)
                            Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")  // Latitude
                            Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")") // Longitude
                            Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m") // Accuracy in meters
                            Text("Altitude: \(location.altitude, specifier: "%.1f")m")         // Altitude in meters
                            Text("Speed: \(location.speed >= 0 ? "\(location.speed, specifier: "%.1f") m/s" : "Unknown")") // Speed if available
                            Text("Timestamp: \(location.timestamp, formatter: dateFormatter)") // Timestamp of location data
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1)) // Light green background
                        .cornerRadius(10)
                        
                    } else if let error = locationService.locationError {
                        // If there's an error getting location, display it
                        VStack {
                            Text("❌ Location Error")
                                .font(.headline)
                            Text(error)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1)) // Light red background for error state
                        .cornerRadius(10)
                        
                    } else {
                        // If no location or error yet, show a "waiting" message
                        Text("🔍 Ready to get location...")
                            .padding()
                            .background(Color.blue.opacity(0.1)) // Light blue background
                            .cornerRadius(10)
                    }
                }
                
                // Button to manually refresh location
                Button("Refresh Location") {
                    locationService.requestLocation()
                }
                .buttonStyle(.borderedProminent) // Prominent button style
                .disabled(
                    locationService.authorizationStatus == .denied ||      // Disabled if permission denied
                    locationService.authorizationStatus == .restricted    // or restricted
                )
                
                // MARK: Authorization Status Display
                Text("Status: \(authorizationStatusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Location Info") // Title for the navigation bar
        }
    }
    
    // MARK: - Authorization Status Text
    // Converts CoreLocation authorization status into user-friendly text.
    private var authorizationStatusText: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Not asked for permission yet"
        case .denied:
            return "Location access denied"
        case .restricted:
            return "Location access restricted"
        case .authorizedWhenInUse:
            return "Location authorized when in use"
        case .authorizedAlways:
            return "Location always authorized"
        @unknown default:
            return "Unknown status"
        }
    }
    
    // MARK: - Date Formatter
    // Formats the timestamp of the location update into a readable time format.
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none    // No date displayed
        formatter.timeStyle = .medium  // Medium time style (e.g. 3:45:27 PM)
        return formatter
    }()
}

// MARK: - Settings View
// Displays app information, version, and planned features.
struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title
                Text("Settings")
                    .font(.largeTitle)
                    .padding()
                
                VStack(alignment: .leading, spacing: 15) {
                    // App title and version
                    Text("Offline Map Navigator")
                        .font(.headline)
                    
                    Text("Version 1.0")
                        .foregroundColor(.secondary)
                    
                    Divider() // Horizontal line
                    
                    // Planned future features
                    Text("Future Features:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• Offline map downloads")
                        Text("• Turn-by-turn navigation")
                        Text("• Route planning")
                        Text("• POI search")
                        Text("• Multiple transport modes")
                    }
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Attribution to OpenStreetMap contributors
                    Text("Map data © OpenStreetMap contributors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Preview Provider
// SwiftUI preview for Xcode canvas.
#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
