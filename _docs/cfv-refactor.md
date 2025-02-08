ContentFeedView (sightline/Views/ContentFeedView):

ContentFeedView.swift: This view is doing too much. It handles UI layout, data loading, and navigation.

Extract subviews: Break down the UI into smaller, reusable components (e.g., a NeighborhoodSelector view, a CategorySelector view).

Move navigation logic to the ViewModel: The ContentFeedViewModel should handle the presentation of the PlaceDetailView. Use a Combine publisher in the ViewModel to signal when a place is selected, and use .sheet(item: Binding) in the ContentFeedView to present the detail view based on this publisher.

Use a dedicated loading/empty state view: Create a separate LoadingView and EmptyStateView and use them consistently.

ContentFeedViewModel.swift: This ViewModel is becoming large.

Decouple from View: Make this ViewModel more generic, and not so tightly coupled to the ContentFeedView and VerticalFeedView. Create separate ViewModels for the Neighborhood and Category selection.

Use Combine publishers for data updates: Use @Published properties and Combine publishers to notify the view of data changes (e.g., when content is loaded, when the selected neighborhood changes).

Delegate loading to Services: The ViewModel should call methods on the service layer (e.g., NeighborhoodService, ContentService) to fetch data, and the service layer should handle the actual interaction with Firestore.