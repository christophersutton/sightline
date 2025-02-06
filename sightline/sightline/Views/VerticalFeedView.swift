import SwiftUI
import UIKit

struct VerticalFeedView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    @Binding var currentIndex: Int
    let itemCount: Int
    let onIndexChanged: (Int) -> Void
    
    init(currentIndex: Binding<Int>, 
         itemCount: Int,
         onIndexChanged: @escaping (Int) -> Void,
         @ViewBuilder content: () -> Content) {
        self.content = content()
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
        
        // Disable system gestures that might interfere with our vertical scroll
        controller.view.gestureRecognizers?.forEach { gesture in
            gesture.addTarget(context.coordinator, action: #selector(Coordinator.handleGesture(_:)))
        }
        
        // Set up the initial view controller
        let hostingController = context.coordinator.hostingController(for: currentIndex)
        controller.setViewControllers([hostingController], direction: .forward, animated: false)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        // Update if the current index changed externally
        if context.coordinator.currentIndex != currentIndex {
            let newVC = context.coordinator.hostingController(for: currentIndex)
            let direction: UIPageViewController.NavigationDirection = context.coordinator.currentIndex > currentIndex ? .reverse : .forward
            uiViewController.setViewControllers([newVC], direction: direction, animated: true)
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
            
            let view = AnyView(
                parent.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            )
            
            let hostingController = UIHostingController(rootView: view)
            hostingController.view.backgroundColor = .clear
            hostingControllers[index] = hostingController
            return hostingController
        }
        
        // MARK: - UIPageViewControllerDataSource
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            let index = currentIndex - 1
            guard index >= 0 else { return nil }
            return hostingController(for: index)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            let index = currentIndex + 1
            guard index < parent.itemCount else { return nil }
            return hostingController(for: index)
        }
        
        // MARK: - UIPageViewControllerDelegate
        
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed,
                  let visibleViewController = pageViewController.viewControllers?.first,
                  let index = hostingControllers.first(where: { $0.value == visibleViewController })?.key
            else { return }
            
            currentIndex = index
            parent.onIndexChanged(index)
        }
        
        @objc func handleGesture(_ gesture: UIGestureRecognizer) {
            // Prevent horizontal swipes from triggering system back gesture
            if let gesture = gesture as? UIPanGestureRecognizer {
                let translation = gesture.translation(in: gesture.view)
                if abs(translation.x) > abs(translation.y) {
                    gesture.state = .failed
                }
            }
        }
    }
}
