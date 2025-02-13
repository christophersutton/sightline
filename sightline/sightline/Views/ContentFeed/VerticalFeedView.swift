import SwiftUI
import UIKit

struct VerticalFeedView<Content: View>: UIViewControllerRepresentable {
    let content: (Int) -> Content
    @Binding var currentIndex: Int
    let itemCount: Int
    
    // Changed this closure signature to provide oldIndex & newIndex
    let onIndexChanged: (Int, Int) -> Void
    
    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        onIndexChanged: @escaping (Int, Int) -> Void,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.content = content
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.onIndexChanged = onIndexChanged
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
        
        // Set up the initial view controller
        let hostingController = context.coordinator.hostingController(for: currentIndex)
        controller.setViewControllers([hostingController], direction: .forward, animated: false)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        // Handle external index changes
        if context.coordinator.currentIndex != currentIndex {
            let newVC = context.coordinator.hostingController(for: currentIndex)
            let direction: UIPageViewController.NavigationDirection =
                context.coordinator.currentIndex > currentIndex ? .reverse : .forward
            
            let shouldAnimate = abs(context.coordinator.currentIndex - currentIndex) <= 1
            uiViewController.setViewControllers([newVC], direction: direction, animated: shouldAnimate)
            context.coordinator.currentIndex = currentIndex
        }
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalFeedView
        var currentIndex: Int
        var hostingControllers: [Int: UIHostingController<AnyView>] = [:]
        
        init(_ verticalFeedView: VerticalFeedView) {
            self.parent = verticalFeedView
            self.currentIndex = verticalFeedView.currentIndex
        }
        
        func hostingController(for index: Int) -> UIHostingController<AnyView> {
            if let existingController = hostingControllers[index] {
                return existingController
            }
            
            guard index >= 0 && index < parent.itemCount else {
                // Return an empty view if index is out of bounds
                let fallbackView = AnyView(Color.black)
                let fallbackController = UIHostingController(rootView: fallbackView)
                fallbackController.view.backgroundColor = .clear
                return fallbackController
            }
            
            let view = AnyView(
                parent.content(index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            )
            
            let newController = UIHostingController(rootView: view)
            newController.view.backgroundColor = .clear
            hostingControllers[index] = newController
            
            cleanupDistantControllers(from: index)
            return newController
        }
        
        private func cleanupDistantControllers(from currentIndex: Int) {
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
            guard
                completed,
                let visibleViewController = pageViewController.viewControllers?.first,
                let newIndex = hostingControllers.first(where: { $0.value == visibleViewController })?.key
            else { return }
            
            let oldIndex = currentIndex
            currentIndex = newIndex
            parent.onIndexChanged(oldIndex, newIndex)
        }
    }
}