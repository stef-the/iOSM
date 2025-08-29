//
//  MapView.swift
//  iOSM
//
//  Fixed version using MapLibre SwiftUI
//

import SwiftUI
import CoreLocation
import MapLibreSwiftUI

struct MapView: View {
    @StateObject private var locationService = LocationService()
    @State private var userLocation: CLLocation?
    @State private var showDebugInfo = false
    @State private var isFollowingUser = false
    @State private var camera = MapViewCamera.center(
        CLLocationCoordinate2D(latitude: 54.6454, longitude: -1.8463),
        zoom: 12
    )
    @State private var annotations: [MapAnnotation] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // MapLibre SwiftUI map
            MapView(
                styleURL: URL(string: "https://demotiles.maplibre.org/style.json")!
            ) {
                // Add user location if available
                if let location = userLocation {
                    CircleAnnotation(centerCoordinate: location.coordinate)
                        .circleColor(.blue)
                        .circleRadius(10)
                        .circleStrokeColor(.white)
                        .circleStrokeWidth(2)
                }
                
                // Add custom annotations
                ForEach(annotations, id: \.id) { annotation in
                    SymbolAnnotation(coordinate: annotation.coordinate)
                        .iconImage("marker")
                        .textField(annotation.title)
                        .textColor(.black)
                        .textSize(12)
                }
            }
            .mapViewCamera($camera)
            .onAppear {
                print("MapView appeared - starting location tracking")
                locationService.startTracking()
            }
            .onDisappear {
                print("MapView disappeared - stopping location tracking")
                locationService.stopTracking()
            }
            .onChange(of: locationService.location) { oldValue, newValue in
                userLocation = newValue
                if isFollowingUser, let location = newValue {
                    camera = MapViewCamera.center(location.coordinate, zoom: camera.zoom ?? 15)
                }
            }
            
            // Enhanced bottom control panel
            VStack(spacing: 10) {
                HStack {
                    // Navigation status info
                    VStack(alignment: .leading, spacing: 4) {
                        if let location = userLocation {
                            Text("Navigation Active")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Lat: \(location.coordinate.latitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Lon: \(location.coordinate.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Speed: \(locationService.speedString)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            if let heading = locationService.heading {
                                Text("Heading: \(locationService.headingString)")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                            }
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
                                Text("Starting navigation...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Navigation control buttons
                    VStack(spacing: 8) {
                        // Follow user toggle
                        Button(action: {
                            isFollowingUser.toggle()
                            if isFollowingUser, let location = userLocation {
                                camera = MapViewCamera.center(location.coordinate, zoom: 16)
                            }
                        }) {
                            Image(systemName: isFollowingUser ? "location.fill" : "location")
                                .foregroundColor(isFollowingUser ? .blue : .gray)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        // Manual center button
                        Button("Center") {
                            if let location = userLocation {
                                camera = MapViewCamera.center(location.coordinate, zoom: 16)
                            } else {
                                locationService.startTracking()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        // Add waypoint pin
                        Button("Add Pin") {
                            if let location = userLocation {
                                addMarker(at: location.coordinate, title: "Waypoint")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(userLocation == nil)
                        
                        // Clear all markers
                        Button("Clear") {
                            annotations.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // Status bar with tracking info
                HStack {
                    Button("Debug") {
                        showDebugInfo.toggle()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    // Tracking status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(locationService.isTracking && userLocation != nil ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(trackingStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("MapLibre GL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Expandable debug information
                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                        
                        Text("Navigation Debug Info")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Group {
                            Text("Location Authorization: \(authorizationStatusText)")
                            Text("Tracking Status: \(locationService.isTracking ? "Active" : "Stopped")")
                            Text("Follow Mode: \(isFollowingUser ? "ON" : "OFF")")
                            Text("Annotations: \(annotations.count)")
                            
                            if let location = userLocation {
                                Text("Accuracy: ±\(location.horizontalAccuracy, specifier: "%.1f")m")
                                Text("Altitude: \(location.altitude, specifier: "%.1f")m")
                                Text("Course: \(location.course >= 0 ? "\(location.course, specifier: "%.1f")°" : "Unknown")")
                                Text("Last Update: \(locationService.isLocationRecent ? "Recent" : "Stale")")
                            }
                            
                            if let zoom = camera.zoom {
                                Text("Zoom Level: \(zoom, specifier: "%.1f")")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        // Manual control buttons
                        HStack {
                            Button(locationService.isTracking ? "Stop Tracking" : "Start Tracking") {
                                if locationService.isTracking {
                                    locationService.stopTracking()
                                } else {
                                    locationService.startTracking()
                                }
                            }
                            
                            Button("One-time Location") {
                                locationService.requestLocation()
                            }
                            
                            Button("Test Marker") {
                                addMarker(at: CLLocationCoordinate2D(latitude: 54.6454, longitude: -1.8463), title: "Test")
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
    }
    
    // MARK: - Helper Methods
    
    private func addMarker(at coordinate: CLLocationCoordinate2D, title: String) {
        let newAnnotation = MapAnnotation(
            id: UUID(),
            coordinate: coordinate,
            title: title
        )
        annotations.append(newAnnotation)
        print("Added marker at: \(coordinate) - \(title)")
    }
    
    // MARK: - Helper Properties
    
    private var trackingStatusText: String {
        if locationService.isTracking && userLocation != nil {
            return "Navigating"
        } else if locationService.isTracking {
            return "Searching..."
        } else {
            return "Stopped"
        }
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
}

// MARK: - Map Annotation Model
struct MapAnnotation {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

// MARK: - Preview
#Preview {
    MapView()
}
