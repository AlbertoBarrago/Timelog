import WidgetKit
import SwiftUI

@main
struct TimelogWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        TimelogWidgetExtension()
        TimelogWidgetExtensionLiveActivity()
    }
}
