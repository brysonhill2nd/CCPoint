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
    
    @Published var currentLocation: String? = "Riverside Courts" // Default for demo
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func checkAuthorizationStatus() {
        switch locationManager.authorizationStatus {
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
        locationManager.requestLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // Get friendly location name from coordinates
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let placemark = placemarks?.first else {
                DispatchQueue.main.async {
                    self?.currentLocation = "Unknown Location"
                }
                return
            }
            
            DispatchQueue.main.async {
                // Try to get a meaningful location name
                if let name = placemark.name,
                   !name.contains("+") { // Avoid coordinate-based names
                    self?.currentLocation = name
                } else if let locality = placemark.locality {
                    // Use neighborhood or city
                    if let subLocality = placemark.subLocality {
                        self?.currentLocation = "\(subLocality), \(locality)"
                    } else {
                        self?.currentLocation = locality
                    }
                } else if let administrativeArea = placemark.administrativeArea {
                    self?.currentLocation = administrativeArea
                } else {
                    self?.currentLocation = "Unknown Location"
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorizationStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentCoordinate = location.coordinate
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        // Keep default location on error
    }
}