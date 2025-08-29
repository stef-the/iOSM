//
//  LocationService.swift
//  iOSM
//
//  Enhanced version with continuous tracking for navigation
//

import Foundation
import CoreLocation
import SwiftUI

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var heading: CLHeading?
    @Published var isTracking = false
    
    private let locationManager = CLLocationManager()
    private var lastLocationUpdate: Date = Date()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // Request one-time location (existing functionality)
    func requestLocation() {
        locationError = nil
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default:
            locationError = "Unknown authorization status"
        }
    }
    
    // Start continuous location tracking (new for navigation)
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocation()
            return
        }
        
        locationError = nil
        isTracking = true
        
        // Configure for navigation
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 3.0 // More sensitive for navigation
        
        // Start location updates
        locationManager.startUpdatingLocation()
        
        // Start heading updates for compass functionality
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        print("Started continuous location tracking")
    }
    
    // Stop continuous tracking
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        
        // Reset to less sensitive settings
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0
        
        print("Stopped continuous location tracking")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out old or inaccurate readings
        let locationAge = newLocation.timestamp.timeIntervalSinceNow
        if abs(locationAge) > 5.0 { return } // Ignore readings older than 5 seconds
        if newLocation.horizontalAccuracy > 100 { return } // Ignore inaccurate readings
        
        // Update location and clear any errors
        self.location = newLocation
        self.locationError = nil
        self.lastLocationUpdate = Date()
        
        if isTracking {
            print("Location updated: \(newLocation.coordinate) (±\(newLocation.horizontalAccuracy)m)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Only accept accurate headings
        if newHeading.headingAccuracy < 0 { return }
        
        self.heading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to get location: \(error.localizedDescription)"
        print("Location error: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                startTracking() // Restart tracking if it was active
            } else {
                locationManager.requestLocation() // Just get one location
            }
        case .denied, .restricted:
            stopTracking()
            locationError = "Location access denied"
        case .notDetermined:
            break
        @unknown default:
            locationError = "Unknown authorization status"
        }
    }
    
    // MARK: - Utility Methods
    
    var isLocationRecent: Bool {
        guard let _ = location else { return false }
        return Date().timeIntervalSince(lastLocationUpdate) < 30 // Location is recent if within 30 seconds
    }
    
    var speedString: String {
        guard let location = location, location.speed >= 0 else { return "Unknown" }
        let speedKmh = location.speed * 3.6 // Convert m/s to km/h
        return String(format: "%.1f km/h", speedKmh)
    }
    
    var headingString: String {
        guard let heading = heading else { return "Unknown" }
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading.trueHeading + 22.5) / 45.0) % 8
        return "\(directions[index]) (\(Int(heading.trueHeading))°)"
    }
}
