//
//  LocationManager.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/21/25.
//


import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: String? = nil
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var isAuthorized = false
    @Published var isLoadingLocation = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Authorization status will be handled by locationManagerDidChangeAuthorization delegate
    }

    func requestAuthorization() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            updateAuthorizationStatus(status)
        }
    }

    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            startUpdatingLocation()
        case .notDetermined:
            isAuthorized = false
        case .denied, .restricted:
            isAuthorized = false
            // Use default location
            currentLocation = "Riverside Courts"
        @unknown default:
            isAuthorized = false
        }
    }
    
    func startUpdatingLocation() {
        guard isAuthorized else { return }
        isLoadingLocation = true
        locationManager.requestLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // Get friendly location name from coordinates
    // Priority: POI name > Venue name > Street name > Neighborhood > City
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let placemark = placemarks?.first else {
                DispatchQueue.main.async {
                    self?.currentLocation = "Unknown Location"
                    self?.isLoadingLocation = false
                }
                return
            }

            DispatchQueue.main.async {
                var locationName: String?

                // PRIORITY 1: Areas of Interest (POI) - This gets "Asoke Sports Club", "Hemingway Park", etc.
                if let areasOfInterest = placemark.areasOfInterest,
                   let poi = areasOfInterest.first {
                    locationName = poi
                }

                // PRIORITY 2: Venue/Building name (for specific locations)
                else if let name = placemark.name,
                        !name.contains("+"), // Avoid coordinate-based names
                        !name.contains(","), // Avoid full addresses
                        name.count < 40 { // Avoid long address strings
                    // Check if it looks like a venue name (not just a street number)
                    let hasDigitsOnly = name.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
                    if !hasDigitsOnly {
                        locationName = name
                    }
                }

                // PRIORITY 3: Thoroughfare (street name) - only if it looks good
                if locationName == nil,
                   let thoroughfare = placemark.thoroughfare,
                   !thoroughfare.isEmpty {
                    // Only use if it's not just a number
                    let hasDigitsOnly = thoroughfare.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
                    if !hasDigitsOnly {
                        locationName = thoroughfare
                    }
                }

                // PRIORITY 4: Sub-locality (neighborhood)
                if locationName == nil,
                   let subLocality = placemark.subLocality {
                    locationName = subLocality
                }

                // PRIORITY 5: Locality (city)
                if locationName == nil,
                   let locality = placemark.locality {
                    locationName = locality
                }

                // PRIORITY 6: Administrative area (state/province)
                if locationName == nil,
                   let administrativeArea = placemark.administrativeArea {
                    locationName = administrativeArea
                }

                // Final fallback
                self?.currentLocation = locationName ?? "Unknown Location"
                self?.isLoadingLocation = false

                print("📍 Location detected: \(self?.currentLocation ?? "nil")")
                print("📍 Debug - POI: \(placemark.areasOfInterest?.joined(separator: ", ") ?? "none")")
                print("📍 Debug - Name: \(placemark.name ?? "none")")
                print("📍 Debug - Thoroughfare: \(placemark.thoroughfare ?? "none")")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorizationStatus(manager.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentCoordinate = location.coordinate
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location manager error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.currentLocation = "Location Unavailable"
            self.isLoadingLocation = false
        }
    }
}
