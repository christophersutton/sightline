import SwiftUI
import UIKit

struct VerticalFeedView<Content: View>: UIViewControllerRepresentable {
    /// The closure now has two parameters: (newIndex, oldIndex).
    let onIndexChanged: (Int, Int) -> Void
    let content: (Int) -> Content
    
    @Binding var currentIndex: Int
    let itemCount: Int
    
    // feedVersion triggers a forced refresh if changed
    let feedVersion: Int
    
    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        feedVersion: Int,
        onIndexChanged: @escaping (Int, Int) -> Void,
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
        
        // Ensure currentIndex is within bounds
        guard currentIndex >= 0 && currentIndex < itemCount else {
            DispatchQueue.main.async {
                self.currentIndex = max(0, min(self.itemCount - 1, self.currentIndex))
            }
            return
        }
        
        // If feedVersion changed, forcibly reload
        if coordinator.feedVersion != feedVersion {
            coordinator.feedVersion = feedVersion
            coordinator.hostingControllers.removeAll()
            
            let newVC = coordinator.hostingController(for: currentIndex)
            uiViewController.setViewControllers([newVC], direction: .forward, animated: false)
            coordinator.currentIndex = currentIndex
            return
        }
        
        // If the user scrolled or we programmatically changed currentIndex
        if coordinator.currentIndex != currentIndex {
            let direction: UIPageViewController.NavigationDirection =
                coordinator.currentIndex > currentIndex ? .reverse : .forward
            let newVC = coordinator.hostingController(for: currentIndex)
            let shouldAnimate = abs(coordinator.currentIndex - currentIndex) <= 1
            uiViewController.setViewControllers([newVC], direction: direction, animated: shouldAnimate)
            
            // Now update coordinator
            let oldIndex = coordinator.currentIndex
            coordinator.currentIndex = currentIndex
            // Fire the callback so we can handle pause logic, etc.
            onIndexChanged(currentIndex, oldIndex)
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
            guard index >= 0 && index < parent.itemCount else {
                return UIHostingController(rootView: AnyView(Color.black))
            }
            if let existing = hostingControllers[index] {
                return existing
            }
            let newView = AnyView(
                parent.content(index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            )
            let controller = UIHostingController(rootView: newView)
            controller.view.backgroundColor = .clear
            hostingControllers[index] = controller
            cleanupDistantControllers(from: index)
            return controller
        }
        
        private func cleanupDistantControllers(from currentIndex: Int) {
            // Keep a small window of pages around
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
                  let visibleVC = pageViewController.viewControllers?.first,
                  let newIndex = hostingControllers.first(where: { $0.value == visibleVC })?.key
            else { return }
            
            let oldIndex = currentIndex
            currentIndex = newIndex
            
            // Fire the callback to the parent
            parent.onIndexChanged(newIndex, oldIndex)
        }
    }
}