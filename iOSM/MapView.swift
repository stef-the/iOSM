//
//  MapView.swift
//  iOSM
//
//  Created by stef on 8/29/25.
//

import SwiftUI
import CoreLocation

struct MapView: View {
    @StateObject private var locationService = LocationService()
    @State private var userLocation: CLLocation?
    @State private var mapLibreMapView = MapLibreMapView(userLocation: .constant(nil))
    @State private var showDebugInfo = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MapLibre map takes most of the screen
            MapLibreMapView(userLocation: $userLocation)
                .onAppear {
                    print("🚀 MapView appeared - requesting location")
                    locationService.requestLocation()
                }
                .onChange(of: locationService.location) { location in
                    print("📱 LocationService updated location: \(location?.coordinate ?? CLLocationCoordinate2D())")
                    userLocation = location
                }
            
            // Bottom control panel
            VStack(spacing: 10) {
                HStack {
                    // Location info
                    VStack(alignment: .leading, spacing: 4) {
                        if let location = userLocation {
                            Text("📍 Location Found")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Lat: \(location.coordinate.latitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Lon: \(location.coordinate.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("±\(location.horizontalAccuracy, specifier: "%.0f")m")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else if let error = locationService.locationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Location Error")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Getting location...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Control buttons
                    VStack(spacing: 8) {
                        Button("Center") {
                            if let location = userLocation {
                                mapLibreMapView.centerOnLocation(location)
                            } else {
                                locationService.requestLocation()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Add Pin") {
                            if let location = userLocation {
                                mapLibreMapView.addMarker(
                                    at: location.coordinate,
                                    title: "My Location"
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(userLocation == nil)
                        
                        Button("Clear") {
                            mapLibreMapView.clearMarkers()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // Debug toggle and map info
                HStack {
                    Button("Debug") {
                        showDebugInfo.toggle()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("🗺️ MapLibre GL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(mapStatusText)
                        .font(.caption)
                        .foregroundColor(mapStatusColor)
                }
                
                // Debug information (collapsible)
                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                        
                        Text("Debug Information")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Group {
                            Text("Location Authorization: \(authorizationStatusText)")
                            Text("Location Service: \(locationService.location != nil ? "Active" : "Inactive")")
                            
                            if let location = userLocation {
                                Text("Speed: \(location.speed >= 0 ? "\(location.speed, specifier: "%.1f") m/s" : "Unknown")")
                                Text("Altitude: \(location.altitude, specifier: "%.1f")m")
                                Text("Updated: \(location.timestamp, formatter: timeFormatter)")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        // Style test buttons
                        HStack {
                            Button("Style 1") {
                                mapLibreMapView.changeStyle(to: "https://demotiles.maplibre.org/style.json")
                            }
                            
                            Button("Style 2") {
                                mapLibreMapView.changeStyle(to: "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json")
                            }
                            
                            Button("Test Pin") {
                                // Add a test pin at Barnard Castle
                                let testCoordinate = CLLocationCoordinate2D(latitude: 54.6454, longitude: -1.8463)
                                mapLibreMapView.addMarker(at: testCoordinate, title: "Test Pin - Barnard Castle")
                            }
                        }
                        .font(.caption2)
                    }
                    .padding(.top, 5)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(radius: 2)
        }
        .onChange(of: userLocation) { oldValue, newValue in
            // Keep the MapLibre view updated
            mapLibreMapView.userLocation = newValue
        }
    }
    
    // MARK: - Helper Properties
    
    private var mapStatusText: String {
        if userLocation != nil {
            return "Online • Location Active"
        } else {
            return "Online • Waiting for Location"
        }
    }
    
    private var mapStatusColor: Color {
        userLocation != nil ? .green : .orange
    }
    
    private var authorizationStatusText: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Preview
#Preview {
    MapView()
}
