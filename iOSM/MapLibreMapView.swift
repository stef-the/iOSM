//
//  MapLibreMapView.swift
//  iOSM
//
//  Created by stef on 8/29/25.
//
import SwiftUI
import MapLibre
import CoreLocation

struct MapLibreMapView: UIViewRepresentable {
    @Binding var userLocation: CLLocation?
    @State private var mapView: MLNMapView?
    
    func makeUIView(context: Context) -> MLNMapView {
        // Create the map view
        let mapView = MLNMapView(frame: .zero)
        
        // Set initial position (Barnard Castle, England)
        let initialCoordinate = CLLocationCoordinate2D(latitude: 54.6454, longitude: -1.8463)
        mapView.setCenter(initialCoordinate, zoomLevel: 12, animated: false)
        
        // Create a simple raster tile source directly instead of using remote style JSON
        let _tileSource = MLNRasterTileSource(
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
        
        // Don't set styleURL, instead configure the style programmatically
        mapView.delegate = context.coordinator
        
        print("Creating basic raster tile map instead of remote style")
        
        // Enable user location
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Set some additional properties for better performance
        mapView.minimumZoomLevel = 1
        mapView.maximumZoomLevel = 20
        
        // Store reference for updates
        self.mapView = mapView
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // Update user location if available
        if let location = userLocation,
           let currentCenter = mapView?.centerCoordinate {
            
            // Only center if map hasn't been moved by user
            let distance = CLLocation(latitude: currentCenter.latitude,
                                    longitude: currentCenter.longitude)
                            .distance(from: location)
            
            // If the map is far from user location (>1km), center on user
            if distance > 1000 {
                uiView.setCenter(location.coordinate, zoomLevel: 15, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapView
        private var styleAttempts = 0
        private let fallbackStyles = [
            "https://demotiles.maplibre.org/style.json",
            "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json"
        ]
        
        init(_ parent: MapLibreMapView) {
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
            print("Map region changed - Center: \(mapView.centerCoordinate), Zoom: \(mapView.zoomLevel)")
        }
    }
    
    // MARK: - Public Methods
    
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
    
    // Utility method to change map style
    func changeStyle(to styleURL: String) {
        guard let url = URL(string: styleURL) else {
            print("Invalid style URL: \(styleURL)")
            return
        }
        
        print("Changing map style to: \(styleURL)")
        mapView?.styleURL = url
    }
}
