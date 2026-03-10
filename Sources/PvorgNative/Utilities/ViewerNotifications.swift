import Foundation

enum ViewerNotifications {
    static let toggleMode = Notification.Name("pvorg.viewer.toggleMode")
    static let previous = Notification.Name("pvorg.viewer.previous")
    static let next = Notification.Name("pvorg.viewer.next")
    static let playPause = Notification.Name("pvorg.viewer.playPause")
    static let seekRelative = Notification.Name("pvorg.viewer.seekRelative")
    static let seekPercent = Notification.Name("pvorg.viewer.seekPercent")
}
