//
//  RoutingService.swift
//  iOSM
//
//  Basic offline routing service (foundation for Valhalla integration)
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Route Models
struct Route: Identifiable {
    let id = UUID()
    let waypoints: [CLLocationCoordinate2D]
    let instructions: [RouteInstruction]
    let totalDistance: Double // in meters
    let estimatedDuration: TimeInterval // in seconds
    let transportMode: TransportMode
    let routeGeometry: [CLLocationCoordinate2D] // Detailed path points
    
    var distanceText: String {
        if totalDistance < 1000 {
            return String(format: "%.0fm", totalDistance)
        } else {
            return String(format: "%.1fkm", totalDistance / 1000)
        }
    }
    
    var durationText: String {
        let hours = Int(estimatedDuration) / 3600
        let minutes = (Int(estimatedDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct RouteInstruction: Identifiable {
    let id = UUID()
    let text: String
    let maneuver: Maneuver
    let distance: Double // Distance to next instruction in meters
    let coordinate: CLLocationCoordinate2D
    let streetName: String?
    
    enum Maneuver {
        case start
        case straight
        case turnLeft
        case turnRight
        case turnSlightLeft
        case turnSlightRight
        case turnSharpLeft
        case turnSharpRight
        case uturn
        case roundaboutEnter
        case roundaboutExit
        case arrive
        
        var icon: String {
            switch self {
            case .start: return "location.circle"
            case .straight: return "arrow.up"
            case .turnLeft: return "arrow.turn.up.left"
            case .turnRight: return "arrow.turn.up.right"
            case .turnSlightLeft: return "arrow.up.left"
            case .turnSlightRight: return "arrow.up.right"
            case .turnSharpLeft: return "arrow.turn.down.left"
            case .turnSharpRight: return "arrow.turn.down.right"
            case .uturn: return "arrow.uturn.up"
            case .roundaboutEnter: return "arrow.3.clockwise"
            case .roundaboutExit: return "arrow.3.clockwise"
            case .arrive: return "mappin.and.ellipse"
            }
        }
    }
}

enum TransportMode: String, CaseIterable {
    case walking = "walking"
    case cycling = "cycling"
    case driving = "driving"
    case publicTransport = "public_transport"
    
    var displayName: String {
        switch self {
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .driving: return "Driving"
        case .publicTransport: return "Public Transport"
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .driving: return "car"
        case .publicTransport: return "bus"
        }
    }
    
    var averageSpeed: Double { // km/h
        switch self {
        case .walking: return 5.0
        case .cycling: return 20.0
        case .driving: return 50.0
        case .publicTransport: return 30.0
        }
    }
}

// MARK: - Routing Service
@MainActor
class RoutingService: ObservableObject {
    @Published var currentRoute: Route?
    @Published var isCalculating = false
    @Published var errorMessage: String?
    @Published var routeProgress: RouteProgress?
    
    // Navigation state
    @Published var isNavigating = false
    @Published var currentInstructionIndex = 0
    @Published var distanceToNextInstruction: Double = 0
    @Published var offRouteDistance: Double = 0
    
    private let locationService: LocationService
    private var routeTrackingTimer: Timer?
    
    init(locationService: LocationService) {
        self.locationService = locationService
    }
    
    // MARK: - Route Calculation
    
    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode = .walking
    ) async {
        isCalculating = true
        errorMessage = nil
        
        // Simulate route calculation (in real implementation, use Valhalla)
        try? await Task.sleep(for: .seconds(2))
        
        let route = await generateSampleRoute(from: start, to: destination, mode: mode)
        
        currentRoute = route
        isCalculating = false
        
        print("Calculated route: \(route.distanceText), \(route.durationText)")
    }
    
    private func generateSampleRoute(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> Route {
        // Calculate straight-line distance
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let straightLineDistance = startLocation.distance(from: destLocation)
        
        // Approximate route distance (add 30% for roads)
        let routeDistance = straightLineDistance * 1.3
        
        // Calculate duration based on transport mode
        let averageSpeedMs = (mode.averageSpeed * 1000) / 3600 // Convert km/h to m/s
        let estimatedDuration = routeDistance / averageSpeedMs
        
        // Generate simple route geometry (straight line with some intermediate points)
        var routeGeometry: [CLLocationCoordinate2D] = []
        let steps = 10
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            let lat = start.latitude + (destination.latitude - start.latitude) * progress
            let lon = start.longitude + (destination.longitude - start.longitude) * progress
            routeGeometry.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // Generate sample instructions
        let instructions = generateSampleInstructions(
            from: start,
            to: destination,
            distance: routeDistance,
            mode: mode
        )
        
        return Route(
            waypoints: [start, destination],
            instructions: instructions,
            totalDistance: routeDistance,
            estimatedDuration: estimatedDuration,
            transportMode: mode,
            routeGeometry: routeGeometry
        )
    }
    
    private func generateSampleInstructions(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        distance: Double,
        mode: TransportMode
    ) -> [RouteInstruction] {
        var instructions: [RouteInstruction] = []
        
        // Start instruction
        instructions.append(RouteInstruction(
            text: "Start \(mode.displayName.lowercased())",
            maneuver: .start,
            distance: distance * 0.4,
            coordinate: start,
            streetName: nil
        ))
        
        // Middle instruction (sample turn)
        let midLat = (start.latitude + destination.latitude) / 2
        let midLon = (start.longitude + destination.longitude) / 2
        let midPoint = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
        
        instructions.append(RouteInstruction(
            text: "Turn right onto Main Street",
            maneuver: .turnRight,
            distance: distance * 0.6,
            coordinate: midPoint,
            streetName: "Main Street"
        ))
        
        // Arrival instruction
        instructions.append(RouteInstruction(
            text: "You have arrived at your destination",
            maneuver: .arrive,
            distance: 0,
            coordinate: destination,
            streetName: nil
        ))
        
        return instructions
    }
    
    // MARK: - Navigation Control
    
    func startNavigation() {
        guard let route = currentRoute else { return }
        
        isNavigating = true
        currentInstructionIndex = 0
        routeProgress = RouteProgress(
            route: route,
            completedDistance: 0,
            remainingDistance: route.totalDistance,
            estimatedTimeRemaining: route.estimatedDuration
        )
        
        startLocationTracking()
        print("Navigation started")
    }
    
    func stopNavigation() {
        isNavigating = false
        routeProgress = nil
        currentInstructionIndex = 0
        stopLocationTracking()
        print("Navigation stopped")
    }
    
    private func startLocationTracking() {
        locationService.startTracking()
        
        routeTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateNavigationProgress()
            }
        }
    }
    
    private func stopLocationTracking() {
        routeTrackingTimer?.invalidate()
        routeTrackingTimer = nil
        locationService.stopTracking()
    }
    
    private func updateNavigationProgress() {
        guard let route = currentRoute,
              let userLocation = locationService.location,
              isNavigating else { return }
        
        let userCoordinate = userLocation.coordinate
        
        // Find closest point on route
        let (closestDistance, closestIndex) = findClosestPointOnRoute(userCoordinate, route: route)
        
        // Check if user is off-route
        offRouteDistance = closestDistance
        let offRouteThreshold: Double = 50 // meters
        
        if closestDistance > offRouteThreshold {
            // User is off route - in a real implementation, recalculate
            print("User is off route by \(closestDistance)m")
            return
        }
        
        // Update instruction progress
        updateInstructionProgress(userCoordinate: userCoordinate, route: route)
        
        // Update overall route progress
        let completedDistance = calculateCompletedDistance(userCoordinate, route: route)
        let remainingDistance = route.totalDistance - completedDistance
        let progress = completedDistance / route.totalDistance
        
        routeProgress = RouteProgress(
            route: route,
            completedDistance: completedDistance,
            remainingDistance: max(0, remainingDistance),
            estimatedTimeRemaining: route.estimatedDuration * (1.0 - progress)
        )
        
        // Check if arrived
        let destinationLocation = CLLocation(
            latitude: route.waypoints.last!.latitude,
            longitude: route.waypoints.last!.longitude
        )
        let distanceToDestination = userLocation.distance(from: destinationLocation)
        
        if distanceToDestination < 20 { // Within 20 meters of destination
            stopNavigation()
            print("Navigation completed - arrived at destination")
        }
    }
    
    private func findClosestPointOnRoute(_ userCoordinate: CLLocationCoordinate2D, route: Route) -> (distance: Double, index: Int) {
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        
        var closestDistance = Double.infinity
        var closestIndex = 0
        
        for (index, point) in route.routeGeometry.enumerated() {
            let pointLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
            let distance = userLocation.distance(from: pointLocation)
            
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        return (closestDistance, closestIndex)
    }
    
    private func updateInstructionProgress(userCoordinate: CLLocationCoordinate2D, route: Route) {
        guard currentInstructionIndex < route.instructions.count else { return }
        
        let currentInstruction = route.instructions[currentInstructionIndex]
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let instructionLocation = CLLocation(
            latitude: currentInstruction.coordinate.latitude,
            longitude: currentInstruction.coordinate.longitude
        )
        
        distanceToNextInstruction = userLocation.distance(from: instructionLocation)
        
        // Check if we should advance to next instruction
        if distanceToNextInstruction < 30 && currentInstructionIndex < route.instructions.count - 1 {
            currentInstructionIndex += 1
            print("Advanced to instruction: \(route.instructions[currentInstructionIndex].text)")
        }
    }
    
    private func calculateCompletedDistance(_ userCoordinate: CLLocationCoordinate2D, route: Route) -> Double {
        // Simplified calculation - in reality, you'd calculate along the route path
        let startLocation = CLLocation(
            latitude: route.waypoints.first!.latitude,
            longitude: route.waypoints.first!.longitude
        )
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        
        return startLocation.distance(from: userLocation)
    }
    
    // MARK: - Utility Methods
    
    func clearRoute() {
        if isNavigating {
            stopNavigation()
        }
        currentRoute = nil
    }
    
    func getCurrentInstruction() -> RouteInstruction? {
        guard let route = currentRoute,
              currentInstructionIndex < route.instructions.count else { return nil }
        return route.instructions[currentInstructionIndex]
    }
    
    func getNextInstruction() -> RouteInstruction? {
        guard let route = currentRoute,
              currentInstructionIndex + 1 < route.instructions.count else { return nil }
        return route.instructions[currentInstructionIndex + 1]
    }
}

// MARK: - Route Progress Model
struct RouteProgress {
    let route: Route
    let completedDistance: Double
    let remainingDistance: Double
    let estimatedTimeRemaining: TimeInterval
    
    var progressPercentage: Double {
        return completedDistance / route.totalDistance
    }
    
    var remainingDistanceText: String {
        if remainingDistance < 1000 {
            return String(format: "%.0fm", remainingDistance)
        } else {
            return String(format: "%.1fkm", remainingDistance / 1000)
        }
    }
    
    var remainingTimeText: String {
        let hours = Int(estimatedTimeRemaining) / 3600
        let minutes = (Int(estimatedTimeRemaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
