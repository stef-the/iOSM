//
//  SearchView.swift
//  iOSM
//
//  Place search interface using offline geocoding
//

import SwiftUI
import CoreLocation
import MapKit

struct SearchView: View {
    @StateObject private var geocodingService = GeocodingService()
    @StateObject private var locationService = LocationService()
    @State private var searchText = ""
    @State private var selectedPlace: Place?
    @State private var showingPlaceDetail = false
    @State private var suggestions: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content based on state
                if geocodingService.isSearching {
                    searchingView
                } else if !searchText.isEmpty && geocodingService.searchResults.isEmpty {
                    noResultsView
                } else if !geocodingService.searchResults.isEmpty {
                    searchResultsList
                } else {
                    welcomeView
                }
                
                Spacer()
            }
            .navigationTitle("Search Places")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationService.requestLocation()
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place, userLocation: locationService.location)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search places, streets, POIs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.count >= 2 {
                            Task {
                                suggestions = await geocodingService.getSuggestions(for: newValue)
                            }
                        } else {
                            suggestions = []
                        }
                        
                        // Clear results when search is cleared
                        if newValue.isEmpty {
                            geocodingService.clearResults()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        geocodingService.clearResults()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            
            // Suggestions dropdown
            if !suggestions.isEmpty && !searchText.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            searchText = suggestion
                            suggestions = []
                            performSearch()
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemBackground))
                        
                        if suggestion != suggestions.last {
                            Divider()
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Content Views
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "map.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Search Offline Places")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Find cities, streets, points of interest and more using our offline database")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 8) {
                SearchSuggestionButton(text: "Barnard Castle", action: {
                    searchText = "Barnard Castle"
                    performSearch()
                })
                
                SearchSuggestionButton(text: "Durham Cathedral", action: {
                    searchText = "Durham Cathedral"
                    performSearch()
                })
                
                SearchSuggestionButton(text: "High Force", action: {
                    searchText = "High Force"
                    performSearch()
                })
            }
            
            // Current location option
            if let location = locationService.location {
                Button("Search near me") {
                    Task {
                        let nearbyPlaces = await geocodingService.reverseGeocode(location.coordinate)
                        await MainActor.run {
                            geocodingService.searchResults = nearbyPlaces
                            searchText = "Near me"
                        }
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try searching for a different place or check your spelling")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Search near me") {
                if let location = locationService.location {
                    Task {
                        let nearbyPlaces = await geocodingService.reverseGeocode(location.coordinate)
                        await MainActor.run {
                            geocodingService.searchResults = nearbyPlaces
                            searchText = "Near me"
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(locationService.location == nil)
        }
        .padding()
    }
    
    private var searchResultsList: some View {
        List {
            Section(header: Text("\(geocodingService.searchResults.count) results")) {
                ForEach(geocodingService.searchResults) { place in
                    PlaceRow(place: place, userLocation: locationService.location) {
                        selectedPlace = place
                        showingPlaceDetail = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndPunctuation).isEmpty else { return }
        
        Task {
            await geocodingService.search(searchText)
        }
    }
}

// MARK: - Search Suggestion Button
struct SearchSuggestionButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(text)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

// MARK: - Place Row
struct PlaceRow: View {
    let place: Place
    let userLocation: CLLocation?
    let onTap: () -> Void
    
    private var distance: String {
        guard let userLocation = userLocation else { return "" }
        let placeLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let distanceInMeters = userLocation.distance(from: placeLocation)
        
        if distanceInMeters < 1000 {
            return String(format: "%.0fm", distanceInMeters)
        } else {
            return String(format: "%.1fkm", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Place type icon
                Image(systemName: place.type.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(place.type.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        if !distance.isEmpty {
                            Text(distance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let address = place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Detail View
struct PlaceDetailView: View {
    let place: Place
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss
    
    private var distance: String {
        guard let userLocation = userLocation else { return "Distance unknown" }
        let placeLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let distanceInMeters = userLocation.distance(from: placeLocation)
        
        if distanceInMeters < 1000 {
            return String(format: "%.0f meters away", distanceInMeters)
        } else {
            return String(format: "%.1f km away", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: place.type.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(place.type.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                            
                            Spacer()
                        }
                        
                        if let address = place.address {
                            Text(address)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Location info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                Text("Coordinates")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(place.coordinate.latitude, specifier: "%.6f"), \(place.coordinate.longitude, specifier: "%.6f")")
                                    .font(.mono(.caption, design: .monospaced))
                            }
                            
                            if userLocation != nil {
                                HStack {
                                    Image(systemName: "ruler")
                                        .foregroundColor(.secondary)
                                    Text("Distance")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(distance)
                                }
                            }
                            
                            if let adminArea = place.adminArea {
                                HStack {
                                    Image(systemName: "map")
                                        .foregroundColor(.secondary)
                                    Text("Region")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(adminArea)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button("Show on Map") {
                            // TODO: Navigate to map view and center on this location
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button("Get Directions") {
                            // TODO: Start navigation to this location
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(userLocation == nil)
                        
                        if userLocation == nil {
                            Text("Enable location services to get directions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Preview
#Preview {
    SearchView()
}
