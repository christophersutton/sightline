enum FilterCategory: String, Codable, CaseIterable, Identifiable {
    case restaurant
    case drinks
    case events
    case music
    case art
    case outdoors
    case shopping
    case coffee
    
    var id: String { rawValue }
} 