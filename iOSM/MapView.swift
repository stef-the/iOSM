//
//  MapView.swift
//  iOSM
//
//  Working version with proper MapLibre integration
//

import SwiftUI
import CoreLocation

struct MapView: View {
    @StateObject private var locationService = LocationService()
    @State private var userLocation: CLLocation?
    @State private var showDebugInfo = false
    @State private var isFollowingUser = false
    @State private var mapController = MapController()
    
    var body: some View {
        VStack(spacing: 0) {
            // MapLibre map takes most of the screen
            MapLibreMapViewWithController(
                userLocation: $userLocation,
                controller: mapController,
                isFollowingUser: $isFollowingUser
            )
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
                                mapController.centerOnLocation(location, zoomLevel: 16)
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
                                mapController.centerOnLocation(location, zoomLevel: 16)
                            } else {
                                // Try to get location if we don't have one
                                locationService.startTracking()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        // Add waypoint pin
                        Button("Add Pin") {
                            if let location = userLocation {
                                mapController.addMarker(
                                    at: location.coordinate,
                                    title: "Waypoint"
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(userLocation == nil)
                        
                        // Clear all markers
                        Button("Clear") {
                            mapController.clearMarkers()
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
                    
                    Text("OSM Tiles")
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
                            
                            if let location = userLocation {
                                Text("Accuracy: ±\(location.horizontalAccuracy, specifier: "%.1f")m")
                                Text("Altitude: \(location.altitude, specifier: "%.1f")m")
                                Text("Course: \(location.course >= 0 ? "\(location.course, specifier: "%.1f")°" : "Unknown")")
                                Text("Last Update: \(locationService.isLocationRecent ? "Recent" : "Stale")")
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

// MARK: - Map Controller Class
class MapController: ObservableObject {
    private weak var mapView: MLNMapView?
    
    func setMapView(_ mapView: MLNMapView) {
        self.mapView = mapView
    }
    
    func centerOnLocation(_ location: CLLocation, zoomLevel: Double = 15) {
        print("Centering map on: \(location.coordinate)")
        mapView?.setCenter(location.coordinate, zoomLevel: zoomLevel, animated: true)
    }
    
    func addMarker(at coordinate: CLLocationCoordinate2D, title: String) {
        print("Adding marker at: \(coordinate) - \(title)")
        let annotation = MLNPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView?.addAnnotation(annotation)
    }
    
    func clearMarkers() {
        print("Clearing all markers")
        guard let annotations = mapView?.annotations else { return }
        mapView?.removeAnnotations(annotations)
    }
}

// MARK: - Enhanced MapLibre View
struct MapLibreMapViewWithController: UIViewRepresentable {
    @Binding var userLocation: CLLocation?
    let controller: MapController
    @Binding var isFollowingUser: Bool
    
    func makeUIView(context: Context) -> MLNMapView {
        // Create the map view
        let mapView = MLNMapView(frame: .zero)
        
        // Set initial position (Barnard Castle, England)
        let initialCoordinate = CLLocationCoordinate2D(latitude: 54.6454, longitude: -1.8463)
        mapView.setCenter(initialCoordinate, zoomLevel: 12, animated: false)
        
        // Configure the map
        mapView.delegate = context.coordinator
        
        // Enable user location
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Set some additional properties for better performance
        mapView.minimumZoomLevel = 1
        mapView.maximumZoomLevel = 20
        
        // Connect to controller
        controller.setMapView(mapView)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // Auto-center if following user and location updates
        if isFollowingUser, let location = userLocation {
            let currentCenter = uiView.centerCoordinate
            let distance = CLLocation(latitude: currentCenter.latitude,
                                    longitude: currentCenter.longitude)
                            .distance(from: location)
            
            // Only center if map is far from user (avoid constant updates)
            if distance > 50 {
                uiView.setCenter(location.coordinate, zoomLevel: uiView.zoomLevel, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapViewWithController
        
        init(_ parent: MapLibreMapViewWithController) {
            self.parent = parent
        }
        
        // Called when map style starts loading
        func mapViewWillStartLoadingMap(_ mapView: MLNMapView) {
            print("MapLibre: Starting to load map...")
        }
        
        // Called when map is ready for style configuration
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            print("MapLibre base style loaded, adding tile layer...")
            
            // Create a simple raster tile source
            let tileSource = MLNRasterTileSource(
                identifier: "osm-tiles",
                tileURLTemplates: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
                options: [
                    .minimumZoomLevel: 0,
                    .maximumZoomLevel: 18,
                    .tileSize: 256,
                    .attributionInfos: [
                        MLNAttributionInfo(title: NSAttributedString(string: "© OpenStreetMap"), url: URL(string: "https://www.openstreetmap.org/copyright"))
                    ]
                ]
            )
            
            // Add the source to the style
            style.addSource(tileSource)
            
            // Create a raster layer
            let rasterLayer = MLNRasterStyleLayer(identifier: "osm-layer", source: tileSource)
            style.addLayer(rasterLayer)
            
            print("Added OpenStreetMap raster tiles to map")
            
            // Add test marker
            let testAnnotation = MLNPointAnnotation()
            testAnnotation.coordinate = mapView.centerCoordinate
            testAnnotation.title = "Barnard Castle"
            testAnnotation.subtitle = "Map with OSM tiles!"
            mapView.addAnnotation(testAnnotation)
        }
        
        // Called when user location updates
        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            if let location = userLocation?.location {
                print("User location updated: \(location.coordinate)")
                DispatchQueue.main.async {
                    self.parent.userLocation = location
                }
            }
        }
        
        // Called when map region changes
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            // Disable follow mode if user manually moves the map
            if animated == false { // User gesture, not programmatic
                DispatchQueue.main.async {
                    self.parent.isFollowingUser = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MapView()
}
