// MARK: - GenerationNotificationService.swift

// Posts macOS user notifications when generations complete while the app is backgrounded.
//
// Uses UNUserNotificationCenter for local notifications with a sound alert.
// Permission is requested on first use. Only sends when the app is not in the foreground.

#if os(macOS)
import Foundation
import UserNotifications

final class GenerationNotificationService {
    static let shared = GenerationNotificationService()

    private var hasRequestedPermission = false

    private init() {}

    func sendCompletionNotification(isVideo: Bool) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = isVideo ? "Video Ready" : "Image Ready"
            content.body = isVideo
                ? "Your video generation completed successfully."
                : "Your image generation completed successfully."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }

    func sendBulkCompletionNotification(sessionName: String, completed: Int, failed: Int) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Bulk Session Complete"

            if failed > 0 {
                content.body = "\(sessionName): \(completed) succeeded, \(failed) failed."
            } else {
                content.body = "\(sessionName): \(completed) image\(completed == 1 ? "" : "s") generated."
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }

    func requestAuthorizationIfNeeded() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                AppLogger.app.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
}
#endif
