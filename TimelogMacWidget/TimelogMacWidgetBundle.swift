import WidgetKit
import SwiftUI
import TimelogCore

@main
struct TimelogMacWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimelogTodayWidget()
    }
}
