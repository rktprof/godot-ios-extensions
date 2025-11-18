//
// This code is public domain. You are free to use under the condition
// you accept that no warranty is given or implied. Use at your own risk.
//
import SwiftGodot
import Foundation
import UserNotifications

#initSwiftExtension(cdecl: "swift_entry_point", types: [LocalNotifications.self])

@Godot
class LocalNotifications:RefCounted {

    let HOUR:Int = 60 * 60

    var permitted = false
    var notificationAccepted = false

    /**
           Display the local notification permission poup box. Check the value of `permitted` after completed.
     */
    @Callable
    func requestPermission(onComplete:Callable) {
        Task {
            let notificationCenter = UNUserNotificationCenter.current()
            let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
        
            let options = await notificationCenter.notificationSettings()
            if options.badgeSetting == .enabled {
                GD.print("Already Authorised")
                self.permitted = true
                onComplete.callDeferred()
                return
            }

            do {
                GD.print("Requesting Authorisation")
                let authorizationGranted = try await notificationCenter.requestAuthorization(options: authorizationOptions)
                self.permitted = authorizationGranted
                onComplete.callDeferred()
            } catch {
                GD.print("Authorisation request failed. \(error.localizedDescription)")
                self.permitted = false
            }
        }
    }
    
    @Callable
    func isPermitted() -> Bool {
        self.permitted
    }

    @Callable
    func wasNotificationAccepted() -> Bool {
        self.notificationAccepted
    }

    @Callable
    func removeAllNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        let pending = notificationCenter.removeAllPendingNotificationRequests()
    }

    @Callable
    func removeNotification(uid:String) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [uid])
    }

    /**
        Request that a notification banner be displayed in the future, as long
        as the user is not inside the application. `reqeustPermission()` must
        be called first.

        - parameter uid: Random string or identifier used to delete this notification later if needed
        - parameter title: title of the local notification.
        - parameter body: text body of the local notification.
        - parameter seconds: display notification in how many seconds time.
        - returns no value is instantly expected. onComplete read the variable `notificationAccepted`
     */
    @Callable
    func schedule(_ uid:String, _ title:String, _ body:String, _ seconds:Int, _ onComplete:Callable) {
        Task {
            if await hasPendingNotification(uid:uid) {
                GD.print("Notification already exists with UID \(uid). Rescheduling.")
                await removeNotification(uid:uid)
            }
            self.notificationAccepted = false

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
        
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval:  TimeInterval(seconds), repeats: false)
            let request = UNNotificationRequest(identifier: uid, content: content, trigger: trigger)

            do {
                try await UNUserNotificationCenter.current().add(request)
                GD.print("Scheduled notification \(uid).")
                notificationAccepted = true
                onComplete.callDeferred()
            } catch {
                GD.print("Error scheduling: \(error.localizedDescription)")
                notificationAccepted = false
                onComplete.callDeferred()
            }
        }
    }

    /**
     Schedule a notice for a specific hour of the day tomorrow. This version does not yet take into
     account daylight savings.
     */
    @Callable
    func scheduleTomorrow(_ uid:String, _ title:String, _ body:String, _ hour:Int, _ onComplete:Callable) {
        let now = Date()
        let tomorrow = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTimePreservingSmallerComponents)!
        let interval = tomorrow.timeIntervalSinceReferenceDate - now.timeIntervalSinceReferenceDate
        let seconds = Int(interval.rounded()) + HOUR * hour
        GD.print("Scheduling notification \(uid) in \(seconds)")
        self.schedule(uid, title, body, seconds, onComplete);
    }

    func hasPendingNotification(uid:String) async -> Bool {
        let notificationCenter = UNUserNotificationCenter.current()
        let pending = await notificationCenter.pendingNotificationRequests()
        for p in pending {
            if p.identifier == uid {
                return true
            }
        }
        return false;
    }

}
