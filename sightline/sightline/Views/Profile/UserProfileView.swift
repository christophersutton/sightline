//
//  UserProfileView.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//
import SwiftUI

// Inside ProfileView.swift
struct UserProfileView: View {
    @EnvironmentObject var profileStore: ProfileStore // Use the ProfileStore
    @State private var showProfileMenu = false
    @State private var selectedPlace: Place?
    @State private var showPlaceDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileSection
                    .padding(.top, 60)

                unlockedNeighborhoodsSection

                savedPlacesSection

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
        .background(
            Image("profile-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .onAppear {
            Task {
                await profileStore.loadData() // Use profileStore
            }
        }
        .confirmationDialog("Profile Options", isPresented: $showProfileMenu) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await profileStore.signOut() // Use profileStore
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var profileSection: some View {
        Button(action: { showProfileMenu = true }) {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.black)

                VStack(alignment: .leading) {
                    Text(profileStore.userEmail ?? "") // Use profileStore
                        .font(.headline)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(.black)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 4)
            )
        }
    }

    private var unlockedNeighborhoodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlocked Neighborhoods")
                .font(.title3.bold())
                .foregroundColor(.black)

            if profileStore.unlockedNeighborhoodNames.isEmpty { // Use profileStore
                Button(action: {
                    // TODO: Navigate to camera view (if needed)
                }) {
                    HStack {
                        Text("Unlock your first neighborhood!")
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "camera.fill")
                            .foregroundColor(.black)
                    }
                }
            } else {
                ForEach(profileStore.unlockedNeighborhoodNames, id: \.self) { neighborhood in // Use profileStore
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(neighborhood)
                            .foregroundColor(.black)
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
    }

    private var savedPlacesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Places")
                .font(.title3.bold())
                .foregroundColor(.black)

            if profileStore.savedPlaces.isEmpty { // Use profileStore
                Text("No saved places yet")
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(profileStore.savedPlaces) { place in // Use profileStore
                        PlaceRow(place: place)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                  //No longer need to preload
                                    selectedPlace = place
                                    showPlaceDetail = true
                                }
                            }
                    }
                    .onDelete { indexSet in
                        guard let index = indexSet.first else { return }
                        let place = profileStore.savedPlaces[index] // Use profileStore
                        Task {
                            await profileStore.removeSavedPlace(place) // Use profileStore
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: CGFloat(profileStore.savedPlaces.count * 60)) // Use profileStore
                .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(placeId: place.id, mode: .review)
        }
    }
}

// Simplify PlaceRow back to just showing the content (Keep this)
private struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                Text(place.address)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
    }
}

// Helper Views (Keep this)
struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
