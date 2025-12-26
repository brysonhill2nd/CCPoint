//
//  LocationDataManager.swift
//  PointiOS
//
//  Manages saved court locations with optional GPS support
//

import Foundation
import Combine
import CoreLocation

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
    @Published var detectedLocation: String? = nil  // GPS-detected location suggestion
    @Published var isDetectingLocation = false

    private let locationsKey = "savedLocations"
    private let currentLocationKey = "currentLocation"
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationDelegate: LocationDataManagerDelegate?

    init() {
        loadSavedLocations()
        loadCurrentLocation()
    }

    /// Setup must be called after init to configure the location delegate
    func setupDelegateIfNeeded() {
        guard locationDelegate == nil else { return }
        locationDelegate = LocationDataManagerDelegate(manager: self)
        locationManager.delegate = locationDelegate
    }

    // MARK: - GPS Detection

    /// Triggers GPS location detection and updates detectedLocation
    func detectCurrentLocation() {
        // Ensure delegate is set up before any location operations
        setupDelegateIfNeeded()

        guard CLLocationManager.locationServicesEnabled() else {
            detectedLocation = nil
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = self?.locationManager.authorizationStatus ?? .notDetermined
            DispatchQueue.main.async {
                guard let self else { return }
                guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                    // Request authorization if not determined
                    if status == .notDetermined {
                        self.locationManager.requestWhenInUseAuthorization()
                    }
                    self.detectedLocation = nil
                    self.isDetectingLocation = false
                    return
                }

                self.isDetectingLocation = true
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                self.locationManager.requestLocation()
            }
        }
    }

    /// Call this from CLLocationManagerDelegate when location is received
    func handleLocationUpdate(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isDetectingLocation = false

                guard let placemark = placemarks?.first else {
                    self?.detectedLocation = nil
                    return
                }

                // Get the best location name (same priority as LocationManager)
                var locationName: String?

                // Priority 1: Areas of Interest (POI)
                if let areasOfInterest = placemark.areasOfInterest,
                   let poi = areasOfInterest.first {
                    locationName = poi
                }
                // Priority 2: Venue/Building name
                else if let name = placemark.name,
                        !name.contains("+"),
                        !name.contains(","),
                        name.count < 40 {
                    let hasDigitsOnly = name.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
                    if !hasDigitsOnly {
                        locationName = name
                    }
                }
                // Priority 3: Street name
                if locationName == nil,
                   let thoroughfare = placemark.thoroughfare,
                   !thoroughfare.isEmpty {
                    let hasDigitsOnly = thoroughfare.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
                    if !hasDigitsOnly {
                        locationName = thoroughfare
                    }
                }
                // Priority 4: Neighborhood
                if locationName == nil, let subLocality = placemark.subLocality {
                    locationName = subLocality
                }
                // Priority 5: City
                if locationName == nil, let locality = placemark.locality {
                    locationName = locality
                }

                self?.detectedLocation = locationName
            }
        }
    }

    /// Use the detected GPS location as current (adds to saved if new)
    func useDetectedLocation() {
        guard let detected = detectedLocation else { return }
        setCurrentLocation(detected)
        detectedLocation = nil  // Clear the suggestion after using
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

    /// Resets location data for sign out / account switch
    func resetUserData() {
        savedLocations = [
            SavedLocation(name: "Riverside Courts", isFavorite: true),
            SavedLocation(name: "Downtown Tennis Club"),
            SavedLocation(name: "City Sports Complex")
        ]
        currentLocation = "Riverside Courts"
        detectedLocation = nil
        isDetectingLocation = false
        UserDefaults.standard.removeObject(forKey: locationsKey)
        UserDefaults.standard.removeObject(forKey: currentLocationKey)
    }
}

// MARK: - Location Delegate Handler
class LocationDataManagerDelegate: NSObject, CLLocationManagerDelegate {
    weak var manager: LocationDataManager?

    init(manager: LocationDataManager) {
        self.manager = manager
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.manager?.handleLocationUpdate(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.manager?.isDetectingLocation = false
            self.manager?.detectedLocation = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Re-attempt detection if authorization was just granted
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            self.manager?.detectCurrentLocation()
        }
    }
}
