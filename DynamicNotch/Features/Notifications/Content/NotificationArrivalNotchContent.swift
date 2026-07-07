import SwiftUI

struct NotificationArrivalNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let item: NotificationItem

    var id: String { "notifications.arrival.\(item.id)" }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 180, height: baseHeight)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 160, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(NotificationArrivalNotchView(item: item))
    }
}
