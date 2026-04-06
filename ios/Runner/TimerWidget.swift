import SwiftUI
import WidgetKit
import ActivityKit

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Lock Screen / Notification view
            HStack {
                Circle().fill(Color.purple).frame(width: 40, height: 40)
                    .overlay(Text("⏳").font(.title3))
                
                VStack(alignment: .leading) {
                    Text(context.state.category).font(.headline).foregroundColor(.white)
                    Text("Focus Session").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                
                if let startTime = context.state.startTime, context.state.isRunning {
                    Text(Date(timeIntervalSince1970: startTime / 1000), style: .timer)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                } else {
                    Text("PAUSED").foregroundColor(.orange).fontWeight(.bold)
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (Long press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                         Circle().fill(Color.purple).frame(width: 24, height: 24)
                             .overlay(Text("⏳").font(.caption))
                         Text(context.state.category).fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Elite Timer").font(.caption).foregroundColor(.gray)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        if let startTime = context.state.startTime, context.state.isRunning {
                             Text(Date(timeIntervalSince1970: startTime / 1000), style: .timer)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                        } else {
                             Text("PAUSED").font(.title2).foregroundColor(.orange)
                        }
                    }
                }
            } compactLeading: {
                Text("⏳").foregroundColor(.purple)
            } compactTrailing: {
                if let startTime = context.state.startTime, context.state.isRunning {
                    Text(Date(timeIntervalSince1970: startTime / 1000), style: .timer)
                        .foregroundColor(.purple)
                } else {
                    Text("--:--").foregroundColor(.gray)
                }
            } minimal: {
                Text("⏳")
            }
            .widgetURL(URL(string: "time-tracker://"))
            .keylineTint(Color.purple)
        }
    }
}
