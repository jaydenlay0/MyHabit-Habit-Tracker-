# MyHabits

A native, offline iPhone habit tracker built with SwiftUI, SwiftData and WidgetKit. Requires **iOS 17+** and **Xcode 16+ on macOS**. No packages, server, account, subscription, advertising, analytics or app-managed cloud sync. All habits are available without a limit or paywall.

The original interface uses soft rounded cards, selectable accent colours, small contribution grids and System (default), Light, or Dark appearance. Choose a mode in Settings → Appearance; it applies immediately and is saved locally between launches. Widgets continue to follow the system appearance. It uses SF Symbols, not HabitKit assets.

## Implemented in layers

1. **Habits and persistence:** create and edit names/icons/colours, check in or undo for today, reorder with Edit, archive/restore by swipe, and permanently delete with confirmation. SwiftData stores habits and history locally.
2. **History and statistics:** 12-week daily heatmap with editable past days, weekly intensity view, 28-day list previews, current/longest streaks and all-time completion percentage. Each habit has an editable consecutive-day goal (30 days initially, adjustable from 1 to 3,650 days). Cards and details show the current streak, days remaining, a progress bar and the target; reaching the target shows “Goal reached!” without resetting the streak.
3. **Widgets:** interactive small, medium and large widgets showing the first 2/3/6 active habits in list order. Widget buttons toggle today through an App Intent. The app and extension use the same App Group SwiftData store.
4. **Backups:** export all habits, including archived ones, as versioned JSON. Import validates the entire document before a single save, merging by UUID. Matching habits are overwritten, including their histories; other habits remain. Errors roll back the transaction. No destructive replace-all operation.

## Open, sign and compile in Xcode

1. Open `MyHabits.xcodeproj`. The project and shared scheme are checked in; no generator, CocoaPods or package installation is needed.
2. Select the **MyHabits** target → **Signing & Capabilities**. Choose your Apple development team and change the bundle identifier from `com.example.MyHabits` to a unique identifier, such as `com.yourname.MyHabits`.
3. Select **MyHabitsWidget**, choose the same team, and set its bundle identifier to the app identifier plus `.widget`. Configure the test target’s team/identifier too if requested.
4. Register a unique **App Group**, such as `group.com.yourname.MyHabits`. Enable exactly that group on **both** the app and widget targets in Signing & Capabilities. Replace `group.com.example.MyHabits` in all three places:
   - `Shared/SharedStore.swift`
   - `MyHabits/MyHabits.entitlements`
   - `MyHabitsWidget/MyHabitsWidget.entitlements`
5. Select the **MyHabits** scheme and an iOS 17+ simulator or attached iPhone. Choose **Product → Build** (⌘B), then Run (⌘R).

A development team with App Groups capability is required to install this shared-store/widget build on a physical phone. Personal Team provisioning may not support App Groups; in that case use an Apple Developer Program team. Never remove the shared-store entitlement to work around signing: the app deliberately reports a storage error rather than silently creating a separate widget-inaccessible database.

The target settings generate the application Info.plist; the extension supplies its WidgetKit extension declaration. There are no runtime API keys or environment variables. A custom App Store icon and distribution screenshots are not included; add those before distribution.

## Test

Run **Product → Test** (⌘U). `MyHabitsTests` covers reversible check-ins, new habits, a streak crossing an unfinished today, gaps/longest streaks, calendar day iteration, backup round-tripping/rejection, SwiftData persistence across contexts, reopening an on-disk store with its goal, goal progress before/at/beyond the target, and goal backup/legacy import validation. The shared scheme includes the test target.

On a Mac, the equivalent commands are (substitute an installed simulator from `xcrun simctl list devices available`):

```sh
xcodebuild -list -project MyHabits.xcodeproj
xcodebuild -project MyHabits.xcodeproj -scheme MyHabits \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MyHabits.xcodeproj -scheme MyHabits \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

The Linux authoring environment has no Swift compiler, Apple SDK, simulator or Xcode. Swift syntax parsing, project references, XML/plists and generator repeatability have been checked here; **Swift compilation, XCTest execution, widget behavior and signing have not been verified**. Run the Mac checks above before relying on this build.

### Manual acceptance checks on an iPhone

- Create multiple habits, choose icons/colours, terminate and reopen the app: habits and check-ins should persist.
- Edit a name, reorder with Edit, archive by swiping, restore from View archive, and delete from the detail screen. Cancel deletion once to verify confirmation.
- Before updating an existing installation, export a backup. Rebuild the app and widget together; the added goal field uses a stored default of 30 for automatic SwiftData migration. Confirm existing history and archived habits remain.
- Create a habit with a 7-day goal, edit it to 14, and relaunch to verify the goal persists. Check the card/detail counts before, at and beyond the goal; a missed day restarts progress without changing the longest streak. Export/import to verify goals are retained; backups from before goals were added import with a 30-day goal.
- Check/uncheck today in both list and detail. Tap eligible past dates in the daily heatmap; future and pre-creation cells are disabled. Compare weekly totals, streaks and completion with the daily history.
- In Settings → Appearance, verify System is initially selected. Switch to Light and Dark and confirm the settings sheet, list, detail and editor update. Relaunch to check that the selection persists. Switch back to System and toggle the simulator’s appearance (Features → Toggle Appearance) to verify it follows the device.
- Test larger text, VoiceOver labels, and landscape. Dense heatmap cells are intentionally compact; VoiceOver names every date and state.
- Export a backup using Settings, save it in Files, modify a habit, then import the backup. Confirm matching history is restored and other habits remain. Import malformed JSON or an unsupported version: no data should change.
- Add the MyHabits Home Screen widget (long-press Home Screen → Edit/Add Widget → MyHabits). Toggle a habit there, reopen the app, and verify the same check-in; toggle in the app and verify the widget updates. Check small/medium/large layouts and archived habits disappearing. WidgetKit controls reload timing; midnight refresh is requested, not guaranteed to the second.
- Enable Airplane Mode and repeat create/check-in/reopen/export. No network connection is required. Files locations chosen for backup may themselves use iCloud; choose **On My iPhone** for a local-only backup.
- Change the system date/time zone only on a test device and check midnight behavior. The active app refreshes its date-dependent views every 30 seconds; widgets request a new timeline at midnight.

## Install on a physical iPhone

Connect the phone to your Mac, unlock it, trust the Mac, and enable **Settings → Privacy & Security → Developer Mode** if prompted. Select it as the run destination, allow Xcode to register/provision it, and press ⌘R. If iOS asks, trust the developer under **Settings → General → VPN & Device Management**. Keep the app and widget in the same signed build. Installation needs Apple signing services; using the installed tracker does not.

For distribution use Xcode **Product → Archive** with a suitable distribution team, then Organizer → Distribute App (for example TestFlight or an eligible registered-device route). Developer builds can expire according to the provisioning profile; they are not permanent App Store installs.

## Data and streak rules

- Each habit is a daily habit. There are no reminder permissions or custom schedules in this version.
- One completion per local calendar date, stored as `yyyy-MM-dd` day keys. Historical keys do not move when travelling across time zones. The calendar follows the device settings.
- Current streak counts backwards from today if complete, otherwise yesterday; an incomplete today does not break yesterday’s streak until tomorrow. Longest streak scans history from the creation day through today.
- Completion = completed days ÷ elapsed calendar days from creation through today, rounded to the nearest percentage. Archiving retains history; archived habits’ statistics still use elapsed days through today.
- Weekly columns follow the current locale’s first weekday. They show counts and intensity for the same 12 weeks as the daily heatmap.
- SwiftData uses an explicit shared on-device store with CloudKit disabled. There is no sync service. OS-level device backups are governed by iOS settings. Deleting the app may remove local data; export before uninstalling.
- JSON backups are unencrypted. Imports reject files above 20 MB as a safety limit; this is not a limit on the number of locally created habits.

## Source map

`Shared/`: SwiftData model, calendar/statistics helpers, App Group container and widget refresh marker. `MyHabits/`: SwiftUI list, creation, detail/history, statistics and backups. `MyHabitsWidget/`: timeline provider and interactive check-in App Intent. `MyHabitsTests/`: XCTest coverage.

`scripts/generate_project.py` regenerates the project with the Python standard library. It is optional and overwrites project settings; preserve your signing customisations before rerunning it. Future development should use this existing checkout; no separate Git worktree is required.
