import AppIntents
import WidgetKit
import TimelogCore

struct StartProjectIntent: AppIntent {
    static var title: LocalizedStringResource { "Start tracking" }
    static var description: IntentDescription { "Start a time tracking session for a project." }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Project ID")
    var projectMongoId: String

    @Parameter(title: "Project Name")
    var projectName: String

    init() {
        self.projectMongoId = ""
        self.projectName = ""
    }

    init(mongoId: String, name: String) {
        self.projectMongoId = mongoId
        self.projectName = name
    }

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.savePendingStart(mongoId: projectMongoId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
