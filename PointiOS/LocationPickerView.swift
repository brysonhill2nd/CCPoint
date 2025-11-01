//
//  LocationPickerView.swift
//  PointiOS
//
//  Manual location picker with optional GPS support
//

import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationDataManager: LocationDataManager
    @StateObject private var locationManager = LocationManager()

    @State private var showingAddLocation = false
    @State private var newLocationName = ""
    @State private var isLoadingGPS = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // GPS Quick Select Button
                    Button(action: useGPSLocation) {
                        HStack {
                            if isLoadingGPS {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Current Location")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)

                                if let gpsLocation = locationManager.currentLocation, !isLoadingGPS {
                                    Text(gpsLocation)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .disabled(!locationManager.isAuthorized || isLoadingGPS)
                    .opacity(locationManager.isAuthorized ? 1.0 : 0.5)

                    // Location permission prompt if not authorized
                    if !locationManager.isAuthorized {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)

                            Text("Enable location access in Settings to use GPS")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)

                    // Saved Locations Header
                    HStack {
                        Text("Saved Courts")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: { showingAddLocation = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Saved Locations List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(locationDataManager.sortedLocations) { location in
                                LocationRow(
                                    location: location,
                                    isSelected: locationDataManager.currentLocation == location.name,
                                    onSelect: {
                                        locationDataManager.setCurrentLocation(location.name)
                                        dismiss()
                                    },
                                    onToggleFavorite: {
                                        locationDataManager.toggleFavorite(location)
                                    },
                                    onDelete: {
                                        locationDataManager.deleteLocation(location)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationSheet(
                locationName: $newLocationName,
                onAdd: {
                    if !newLocationName.isEmpty {
                        locationDataManager.addLocation(name: newLocationName)
                        newLocationName = ""
                    }
                    showingAddLocation = false
                }
            )
        }
        .onAppear {
            // Request location authorization if needed
            if !locationManager.isAuthorized {
                locationManager.requestAuthorization()
            } else {
                locationManager.startUpdatingLocation()
            }
        }
    }

    private func useGPSLocation() {
        isLoadingGPS = true
        locationManager.startUpdatingLocation()

        // Wait for location update
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let gpsLocation = locationManager.currentLocation {
                locationDataManager.setCurrentLocation(gpsLocation)
                dismiss()
            }
            isLoadingGPS = false
        }
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: SavedLocation
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Favorite star
                Button(action: onToggleFavorite) {
                    Image(systemName: location.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(location.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(PlainButtonStyle())

                // Location name
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    if let lastUsed = location.lastUsed {
                        Text(formatLastUsed(lastUsed))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatLastUsed(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Used today"
        } else if calendar.isDateInYesterday(date) {
            return "Used yesterday"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Used \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
    }
}

// MARK: - Add Location Sheet

struct AddLocationSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var locationName: String
    let onAdd: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField("Court name", text: $locationName)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    Spacer()
                }
            }
            .navigationTitle("Add Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd()
                    }
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                    .disabled(locationName.isEmpty)
                }
            }
        }
    }
}

struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPickerView()
            .environmentObject(LocationDataManager.shared)
    }
}
