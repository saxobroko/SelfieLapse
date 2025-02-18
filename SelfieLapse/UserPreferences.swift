import Foundation

class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    @Published var isFlashEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFlashEnabled, forKey: "isFlashEnabled")
        }
    }
    
    private init() {
        self.isFlashEnabled = UserDefaults.standard.bool(forKey: "isFlashEnabled")
    }
}