//
//  TestMapView.swift - Temporary file for debugging
//  Add this to your project temporarily to test
//

import SwiftUI
import MapLibre

// Simple test view to isolate the map rendering issue
struct TestMapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        
        // Set background to red to test if MapLibre view is rendering at all
        mapView.backgroundColor = UIColor.red
        
        // Set a very simple, reliable tile source
        mapView.styleURL = URL(string: "https://tiles.versatiles.org/assets/styles/colorful.json")
        
        // Set initial position
        let coordinate = CLLocationCoordinate2D(latitude: 37.3347, longitude: -122.0089)
        mapView.setCenter(coordinate, zoomLevel: 10, animated: false)
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // Nothing needed here for test
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            print("✅ TEST: Map style loaded successfully!")
            // Reset background to default once tiles load
            mapView.backgroundColor = UIColor.clear
        }
        
        func mapView(_ mapView: MLNMapView, didFailToLoadStyleWithError error: Error) {
            print("❌ TEST: Style failed to load: \(error)")
            // Keep red background to show the issue
        }
    }
}

// Test view to replace MapView temporarily
struct TestMapScreen: View {
    var body: some View {
        VStack {
            Text("Testing Map Rendering")
                .font(.headline)
                .padding()
            
            TestMapView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Text("If you see RED, MapLibre view works but tiles don't load")
                .font(.caption)
                .padding()
            Text("If you see map tiles, the issue is elsewhere")
                .font(.caption)
        }
    }
}
