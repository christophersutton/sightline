// sightline/sightline/Views/ContentFeed/ContentItemView.swift
import SwiftUI
import AVKit
import FirebaseStorage

struct ContentItemView: View {
    @EnvironmentObject var appStore: AppStore
    let content: Content
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if appStore.currentContentItem?.id == content.id {
                    if let player = appStore.videoManager.currentPlayer {
                        VideoPlayer(player: player)
                            .edgesIgnoringSafeArea(.all)
                    } else {
                        LoadingView()
                    }
                } else {
                    Color.black
                }
                
                ContentOverlay(content: content)
            }
        }
        .onAppear {
            print("📱 ContentItemView appeared for content: \(content.id)")
            Task {
                await appStore.setCurrentContent(content)
            }
        }
    }
}

// Add this extension to get safe area insets in SwiftUI
private extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        (UIApplication.shared.windows.first?.safeAreaInsets ?? .zero).insets
    }
}

private extension UIEdgeInsets {
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

struct ErrorView: View {
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text("Failed to load video")
                .foregroundColor(.white)
        }
    }
}

struct LoadingView: View {
    var body: some View {
        Color.black
        ProgressView()
            .scaleEffect(1.5)
    }
}

struct ContentOverlay: View {
    let content: Content
    @EnvironmentObject var appStore: AppStore
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(content.caption)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        if let placeId = content.placeIds.first {
                            NavigationLink(value: AppState.NavigationDestination.placeDetail(placeId: placeId, initialContentId: content.id)) {
                                Text(appStore.places[placeId]?.name ?? "Loading place...")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 120)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .padding(.top, -100)
            )
        }
    }
} 
