import SwiftUI
import WidgetKit

@main
struct ZnuniWidgetBundle: WidgetBundle {
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
