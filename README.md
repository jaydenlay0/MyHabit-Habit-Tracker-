# MyHabits

A native, offline iPhone habit tracker built with SwiftUI, SwiftData and WidgetKit. Requires **iOS 17+** and **Xcode 16+ on macOS**. No packages, server, account, subscription, advertising, analytics or app-managed cloud sync. All habits are available without a limit or paywall.

The original interface uses soft rounded cards, selectable accent colours, small contribution grids and System (default), Light, or Dark appearance. Choose a mode in Settings → Appearance; it applies immediately and is saved locally between launches. Widgets continue to follow the system appearance. The editor offers 24 colours in a six-column, four-row palette: four shades each of red, blue, green, yellow, pink (including baby pink), and purple and 18 SF Symbols, including meditation, yoga, basketball, skipping rope, pills and AirPods Max headphones. It uses SF Symbols, not HabitKit assets.

## Implemented in layers

1. **Habits and persistence:** create and edit names/icons/colours, check in or undo for today, reorder with Edit, archive by swipe (with confirmation), and permanently delete with confirmation. SwiftData stores habits and history locally. Home shows only active habits; Settings → Archive storage shows a count and a confirmed permanent-delete option, with no archive browsing or restore action.
2. **History and statistics:** 12-week daily heatmap with editable past days, weekly intensity view, 28-day list previews, current/longest streaks and all-time completion percentage. Streak goals are optional and off by default for new habits. Enable “Streak Goal” in New/Edit habit to choose 1–3,650 consecutive days (initial suggestion: 30). With a goal, cards and details show the current streak, days remaining, a progress bar and target; reaching the target shows “Goal reached!” without resetting the streak. Without a goal, only the current streak is shown. Removing a goal keeps check-ins, heatmaps and statistics.
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
- Edit a name and reorder with Edit. Archive from a swipe or the detail screen: cancel once, then confirm. Verify it disappears from Home, today’s count and widgets, with no View archive button or restore action. Settings → Archive storage should show only a count. Cancel archive deletion once, then confirm it deletes archived habits while keeping active habits and their check-ins. Delete a single active habit from its detail screen and verify confirmation.
- Open New habit and verify six columns and four rows of swatches: red, blue, green, yellow, pink and purple from left to right, with four shades from light to deep. Confirm baby pink is available, selection marks contrast on deep shades, and previously saved colours stay unchanged when editing without selecting a new colour. Select each of the six new icons (meditation, yoga, basketball, skipping rope, pills and AirPods Max), save, relaunch and confirm its appearance in the list, details and widget. Check the grids on smaller screens and with VoiceOver.
- Before updating an existing installation, export a backup. Rebuild the app and widget together; the added goal field uses a stored default of 30 for automatic SwiftData migration. Confirm existing history, goal settings and archived habits remain. Goal-free habits are stored with a zero target without changing the existing SwiftData schema.
- Create and save a new habit with “Streak Goal” off: check that there is no target or progress bar, and the streak still increments. Enable a goal later, disable it again, and relaunch to verify history and the no-goal setting persist. Export/import that habit to verify it remains goal-free.
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
- Completion = completed days ÷ elapsed calendar days from creation through today, rounded to the nearest percentage. Archiving retains history in local storage and exports but removes it from the app’s browsing and daily workflow. Settings can permanently clear archived data. A backup intentionally imported from before archiving can still restore that earlier state.
- Weekly columns follow the current locale’s first weekday. They show counts and intensity for the same 12 weeks as the daily heatmap.
- SwiftData uses an explicit shared on-device store with CloudKit disabled. There is no sync service. OS-level device backups are governed by iOS settings. Deleting the app may remove local data; export before uninstalling.
- JSON backups are unencrypted. Imports reject files above 20 MB as a safety limit; this is not a limit on the number of locally created habits.

## Source map

`Shared/`: SwiftData model, calendar/statistics helpers, App Group container and widget refresh marker. `MyHabits/`: SwiftUI list, creation, detail/history, statistics and backups. `MyHabitsWidget/`: timeline provider and interactive check-in App Intent. `MyHabitsTests/`: XCTest coverage.

`scripts/generate_project.py` regenerates the project with the Python standard library. It is optional and overwrites project settings; preserve your signing customisations before rerunning it. Future development should use this existing checkout; no separate Git worktree is required.
