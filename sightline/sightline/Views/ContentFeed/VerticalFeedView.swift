import SwiftUI
import UIKit

struct VerticalFeedView<Content: View>: UIViewControllerRepresentable {
    let content: (Int) -> Content
    
    @Binding var currentIndex: Int
    let itemCount: Int
    
    // Newly added feedVersion. If it changes, we'll force a reload.
    let feedVersion: Int
    
    let onIndexChanged: (Int) -> Void
    
    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        feedVersion: Int,
        onIndexChanged: @escaping (Int) -> Void,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.feedVersion = feedVersion
        self.onIndexChanged = onIndexChanged
        self.content = content
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: [.interPageSpacing: 0]
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .black
        
        // Disable system gestures that might interfere
        controller.view.gestureRecognizers?.forEach { gesture in
            (gesture as? UIScreenEdgePanGestureRecognizer)?.isEnabled = false
        }
        
        // Set the initial view controller
        let hostingController = context.coordinator.hostingController(for: currentIndex)
        controller.setViewControllers([hostingController], direction: .forward, animated: false)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        
        // Add bounds checking
        guard currentIndex >= 0 && currentIndex < itemCount else {
            // Reset to a valid index if out of bounds
            DispatchQueue.main.async {
                self.currentIndex = max(0, min(self.itemCount - 1, self.currentIndex))
            }
            return
        }
        
        // 1) If feedVersion changes, forcibly reload everything to show new content
        if coordinator.feedVersion != feedVersion {
            coordinator.feedVersion = feedVersion
            coordinator.hostingControllers.removeAll()
            
            let newVC = coordinator.hostingController(for: currentIndex)
            uiViewController.setViewControllers([newVC], direction: .forward, animated: false)
            coordinator.currentIndex = currentIndex
            return
        }
        
        // 2) If user swiped to change currentIndex, update the displayed controller
        if coordinator.currentIndex != currentIndex {
            let newVC = coordinator.hostingController(for: currentIndex)
            let direction: UIPageViewController.NavigationDirection =
                coordinator.currentIndex > currentIndex ? .reverse : .forward
            
            // Only animate if the user moved 1 step
            let shouldAnimate = abs(coordinator.currentIndex - currentIndex) <= 1
            uiViewController.setViewControllers([newVC], direction: direction, animated: shouldAnimate)
            
            coordinator.currentIndex = currentIndex
        }
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalFeedView
        var currentIndex: Int
        var feedVersion: Int
        
        // Cache each page's UIHostingController
        var hostingControllers: [Int: UIHostingController<AnyView>] = [:]
        
        init(_ verticalFeedView: VerticalFeedView) {
            self.parent = verticalFeedView
            self.currentIndex = verticalFeedView.currentIndex
            self.feedVersion = verticalFeedView.feedVersion
        }
        
        func hostingController(for index: Int) -> UIHostingController<AnyView> {
            // If out of bounds, show a blank view
            guard index >= 0 && index < parent.itemCount else {
                return UIHostingController(rootView: AnyView(Color.black))
            }
            if let existingController = hostingControllers[index] {
                return existingController
            }
            // Build a new hosting controller for this index
            let view = AnyView(
                parent.content(index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            )
            let controller = UIHostingController(rootView: view)
            controller.view.backgroundColor = .clear
            hostingControllers[index] = controller
            
            // Clean up distant pages for memory usage
            cleanupDistantControllers(from: index)
            
            return controller
        }
        
        private func cleanupDistantControllers(from currentIndex: Int) {
            // Keep only a few pages around (the current, plus some near neighbors)
            let keepRange = (currentIndex - 2)...(currentIndex + 2)
            hostingControllers = hostingControllers.filter { keepRange.contains($0.key) }
        }
        
        // MARK: - UIPageViewControllerDataSource
        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            let index = currentIndex - 1
            guard index >= 0 else { return nil }
            return hostingController(for: index)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            let index = currentIndex + 1
            guard index < parent.itemCount else { return nil }
            return hostingController(for: index)
        }
        
        // MARK: - UIPageViewControllerDelegate
        func pageViewController(_ pageViewController: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let visibleViewController = pageViewController.viewControllers?.first,
                  let index = hostingControllers.first(where: { $0.value == visibleViewController })?.key
            else { return }
            
            currentIndex = index
            parent.onIndexChanged(index)
        }
    }
}