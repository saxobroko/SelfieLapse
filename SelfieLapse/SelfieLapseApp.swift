import SwiftUI
import SwiftData

@main
struct SelfieLapseApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([Album.self, Photo.self])
            let modelConfiguration = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(modelContainer)
    }
}
