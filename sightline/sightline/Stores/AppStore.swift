//
//  AppStore.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//


// sightline/sightline/Stores/AppStore.swift
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
              currentContentItem = nil // IMMEDIATELY clear the current video
              currentIndex = 0
              Task {
                  await loadContent()
              }
          }
      }

      @Published var selectedCategory: FilterCategory = .restaurant {
          didSet {
              currentContentItem = nil // IMMEDIATELY clear the current video
              currentIndex = 0
              Task {
                  await loadContent()
              }
          }
      }

      @Published var currentIndex: Int = 0 {
          didSet {
            //Prevent out of bounds
            if contentItems.indices.contains(currentIndex) {
              currentContentItem = contentItems[currentIndex]
            }
          }
      }

      // KEY CHANGE:  Publish the *current Content item*
      @Published var currentContentItem: Content? = nil {
          didSet {
              if let videoUrl = currentContentItem?.videoUrl {
                  videoManager.play(url: videoUrl) // ALWAYS play; manager handles preparation
              } else {
                  videoManager.pause() // Pause if no current item
              }
          }
      }

    private var cancellables = Set<AnyCancellable>() // Manage Combine subscriptions

    let videoManager = VideoPlayerManager()

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
              currentContentItem = nil // Ensure video is cleared
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

              // KEY CHANGE: Set currentContentItem *after* loading data
              currentContentItem = contentItems.first
               // Preload *after* setting the current item
              if let firstContent = contentItems.first {
                  let urls = contentItems.map { $0.videoUrl }
                  videoManager.preloadVideos(for: urls, at: 0)
              }

          } catch {
              print("Error loading content: \(error)")
              contentItems = []
              places = [:]
              currentContentItem = nil // Clear on error
          }
      }
}
