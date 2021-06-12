import Foundation

public enum DatabaseError: Error {
    case failedToFetch

    
    public var localizedDescription: String {
        switch self {
        case .failedToFetch:
            return "This means blah failed"
        }
    }
}
