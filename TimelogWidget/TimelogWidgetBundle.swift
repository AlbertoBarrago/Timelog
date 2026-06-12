import WidgetKit
import SwiftUI
import TimelogCore

@main
struct TimelogWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimelogTodayWidget()
    }
}
