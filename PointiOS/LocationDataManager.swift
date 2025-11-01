//
//  LocationDataManager.swift
//  PointiOS
//
//  Manages saved court locations with optional GPS support
//

import Foundation
import Combine

struct SavedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isFavorite: Bool
    var lastUsed: Date?

    init(id: UUID = UUID(), name: String, isFavorite: Bool = false, lastUsed: Date? = nil) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.lastUsed = lastUsed
    }
}

class LocationDataManager: ObservableObject {
    static let shared = LocationDataManager()

    @Published var savedLocations: [SavedLocation] = []
    @Published var currentLocation: String = "Riverside Courts"

    private let locationsKey = "savedLocations"
    private let currentLocationKey = "currentLocation"

    init() {
        loadSavedLocations()
        loadCurrentLocation()
    }

    // MARK: - Load/Save

    private func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: locationsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        } else {
            // Default locations
            savedLocations = [
                SavedLocation(name: "Riverside Courts", isFavorite: true),
                SavedLocation(name: "Downtown Tennis Club"),
                SavedLocation(name: "City Sports Complex")
            ]
            saveLocations()
        }
    }

    private func loadCurrentLocation() {
        if let saved = UserDefaults.standard.string(forKey: currentLocationKey) {
            currentLocation = saved
        }
    }

    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(encoded, forKey: locationsKey)
        }
    }

    // MARK: - Public Methods

    func setCurrentLocation(_ location: String) {
        currentLocation = location
        UserDefaults.standard.set(location, forKey: currentLocationKey)

        // Update last used timestamp
        if let index = savedLocations.firstIndex(where: { $0.name == location }) {
            savedLocations[index].lastUsed = Date()
            saveLocations()
        } else {
            // Add new location if it doesn't exist
            addLocation(name: location)
        }
    }

    func addLocation(name: String, isFavorite: Bool = false) {
        // Check if location already exists
        guard !savedLocations.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            return
        }

        let newLocation = SavedLocation(name: name, isFavorite: isFavorite, lastUsed: Date())
        savedLocations.append(newLocation)
        saveLocations()
    }

    func deleteLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
        saveLocations()

        // If deleted location was current, reset to first location
        if currentLocation == location.name, let first = savedLocations.first {
            setCurrentLocation(first.name)
        }
    }

    func toggleFavorite(_ location: SavedLocation) {
        if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
            savedLocations[index].isFavorite.toggle()
            saveLocations()
        }
    }

    var sortedLocations: [SavedLocation] {
        savedLocations.sorted { location1, location2 in
            // Favorites first
            if location1.isFavorite != location2.isFavorite {
                return location1.isFavorite
            }
            // Then by last used
            if let date1 = location1.lastUsed, let date2 = location2.lastUsed {
                return date1 > date2
            }
            if location1.lastUsed != nil {
                return true
            }
            if location2.lastUsed != nil {
                return false
            }
            // Finally alphabetically
            return location1.name < location2.name
        }
    }
}
