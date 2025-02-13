//
//  EmptyNeighborhoodState.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//
import SwiftUI


struct EmptyNeighborhoodState: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Background Image
                    Image("nocontent")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    // Content Container
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            // Header
                            Text("Unlock Your First Neighborhood")
                                .font(.custom("Baskerville-Bold", size: 28))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                                .opacity(0.9)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Discover local landmarks to unlock neighborhood content and start exploring stories from your community")
                                .font(.custom("Baskerville", size: 18))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 72))
                                .foregroundColor(.black.opacity(0.9))
                                .padding(.top, 8)
                        }
                        .padding(24)
                        .background(.thinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                    }
                    .padding()
                }
                .frame(minHeight: geometry.size.height)
            }
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
    }
}
