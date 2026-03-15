import SwiftUI
import WidgetKit

@main
struct TodayInSwitzerlandWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        NewsWidget()
        SunshineWidget()
        DayPlanWidget()
        WeatherLockScreenWidget()
        NewsLockScreenWidget()
        TransportLockScreenWidget()
        TransportLiveActivity()
    }
}
