//
//  AppStore.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//
import Combine
import FirebaseFirestore
import SwiftUI
@MainActor
class AppStore: Store {
    private let services = ServiceContainer.shared
      @Published var unlockedNeighborhoods: [Neighborhood] = []
      @Published var availableCategories: [FilterCategory] = []
      @Published var contentItems: [Content] = []
      @Published var places: [String: Place] = [:]
      @Published var selectedNeighborhood: Neighborhood? {
          didSet {
              currentIndex = 0
              Task {
                  await loadContent()
              }
          }
      }

      @Published var selectedCategory: FilterCategory = .restaurant {
          didSet {
              currentIndex = 0
              Task {
                  await loadContent()
              }
          }
      }

      @Published var currentIndex: Int = 0

    private var cancellables = Set<AnyCancellable>() // Manage Combine subscriptions

    let videoManager: VideoPlayerManager

    init() {
        self.videoManager = VideoPlayerManager() // This is now safe since AppStore is @MainActor
    }

    func loadUnlockedNeighborhoods() async {
        do {
            let neighborhoods = try await services.neighborhood.fetchUnlockedNeighborhoods()
            unlockedNeighborhoods = neighborhoods
            if selectedNeighborhood == nil ||
                !neighborhoods.contains(where: { $0.id == selectedNeighborhood?.id }) {
                 selectedNeighborhood = neighborhoods.first
             }

        } catch {
            print("Error loading neighborhoods: \(error)")
        }
    }

    func loadAvailableCategories() async {
       guard let neighborhood = selectedNeighborhood else { return }
        do {
            let categories = try await services.neighborhood.fetchAvailableCategories(neighborhoodId: neighborhood.id!)
            availableCategories = categories

            if !categories.contains(selectedCategory) && !categories.isEmpty {
              selectedCategory = categories[0]
            }
        } catch {
            print("Error loading categories: \(error)")
        }
    }

  func loadContent() async {
          guard let neighborhood = selectedNeighborhood else {
              contentItems = []
              places = [:]
              
              return
          }
          do {
              await loadAvailableCategories()
              let content = try await services.content.fetchContent(
                  neighborhoodId: neighborhood.id!,
                  category: selectedCategory
              )

              var placeMap: [String: Place] = [:]
              for item in content {
                  for placeId in item.placeIds {
                      if places[placeId] == nil && placeMap[placeId] == nil {
                          if let place = try? await services.place.fetchPlace(id: placeId) {
                              placeMap[placeId] = place
                          }
                      }
                  }
              }

              contentItems = content
              places.merge(placeMap) { (_, new) in new }

            let videoURLs = content.map { $0.videoUrl }
            videoManager.preloadVideos(for: videoURLs, at: currentIndex)

              
          } catch {
              print("Error loading content: \(error)")
              contentItems = []
              places = [:]
              
          }
      }
    
    func pauseCurrentVideo() {
        videoManager.pause()
    }
}
