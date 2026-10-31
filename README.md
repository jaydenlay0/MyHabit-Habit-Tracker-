# MyHabits

A native, offline iPhone habit tracker built with SwiftUI, SwiftData and WidgetKit. Requires **iOS 17+** and **Xcode 16+ on macOS**. No packages, server, account, subscription, advertising, analytics or app-managed cloud sync. All habits are available without a limit or paywall.

The original interface places a centred MyHabits title and daily summary directly below the toolbar, soft rounded cards, selectable accent colours, small contribution grids and System (default), Light, or Dark appearance. Dark mode uses GitHub-inspired charcoal (#0D1117), lighter surfaces (#161B22), subtle borders, soft white text and neutral empty heatmap cells; light mode retains native iOS styling. Choose a mode in Settings → Appearance; it applies immediately and is saved locally between launches. Widgets continue to follow the system appearance. The editor offers 24 colours in a six-column, four-row palette: four shades each of red, blue, green, yellow, pink (including baby pink), and purple and 25 habit icons (16 SF Symbols and nine original vector icons), including meditation, yoga, basketball, skipping rope, pills and AirPods Max headphones. It uses SF Symbols and its own vector drawing, not HabitKit assets. The retired leaf habit option is displayed as Brushing teeth, including for existing habits and backups. The former music option is Deodorant. Seven additional outline icons cover Shower / Bath, Coding, Studying, Make Bed, Robot Vacuum, Vacuum and Cleaning.

## Implemented in layers

1. **Habits and persistence:** create and edit names/icons/colours, check in or undo for today, reorder with Edit, archive by swipe (with confirmation), and permanently delete with confirmation. SwiftData stores habits and history locally. Home shows only active habits; Settings → Archived habits opens a compact list of icons, names and two-line description previews, with Restore and confirmed Delete permanently actions. Restoring keeps check-in history and returns the habit to the end of Home; reminder schedules refresh after changes.
2. **History and statistics:** 12-week daily heatmap with editable past days, weekly intensity view, 28-day list previews, current/longest streaks and all-time completion percentage. Streak goals are optional and off by default for new habits. Enable “Streak Goal” in New/Edit habit to choose 1–3,650 consecutive days (initial suggestion: 30). With a goal, cards and details show the current streak, days remaining, a progress bar and target; reaching the target shows “Goal reached!” without resetting the streak. Without a goal, only the current streak is shown. Removing a goal keeps check-ins, heatmaps and statistics.
3. **Widgets:** interactive small, medium and large widgets showing the first 2/3/6 active habits in list order. Widget buttons toggle today through an App Intent. The app and extension use the same App Group SwiftData store.
4. **Completion feedback:** completing today in the list, detail screen or today’s heatmap cell triggers a roughly four-second, full-width confetti shower with 192 small pieces spread into a taller falling band falling from top to bottom and a system success haptic after saving succeeds. Consecutive completions add independent showers: earlier confetti keeps falling while new confetti starts at the top, and each shower expires on its own. The background brightens to solid colour immediately on completion, including while the tick is showing. The tick lasts two seconds, then crossfades into the original icon over 0.45 seconds while the bright background stays. Reduce Motion skips these transitions. Undo restores the subdued background and cancels only that habit’s feedback. Past-date edits, relaunches and backup imports do not celebrate. Reduce Motion replaces particles with a quiet acknowledgement. Widget check-ins use the same static completed icon styling; widgets do not play this in-app animation or custom haptic.
5. **Local reminders:** optional, off by default, with the first time set to **10:00 am**. Choose up to three daily times, individual weekdays or Every day. A same-day time window evenly spaces the chosen number of reminders, using the midpoint for a single reminder. iOS notification permission is requested only when saving enabled reminders or explicitly enabling notifications in Settings. Settings reports denied permission and scheduling errors. Editing replaces the schedule; archiving, deleting or switching reminders off removes future alerts. Reminders are repeating local notifications, so they work offline and do not require the app process to stay running.
6. **Backups:** export all habits, including archived ones, as versioned JSON. Import validates the entire document before a single save, merging by UUID. Matching habits are overwritten, including their histories; other habits remain. Errors roll back the transaction. No destructive replace-all operation.

## Install on your iPhone with a free Apple account

Use the **MyHabitsPersonal** scheme. It has the same habit tracking, appearance settings, reminders, confetti and backups, with an app-private SwiftData store. It embeds no widget, declares no App Group, and needs no paid capability.

1. Open `MyHabits.xcodeproj` from the downloaded project.
2. In the Mac menu bar choose **Product → Scheme → MyHabitsPersonal**.
3. Connect and unlock your iPhone, accept **Trust This Computer**, and select your actual phone in Xcode’s device selector.
4. Press **⌘1**, click the blue MyHabits project, select **MyHabitsPersonal** under **TARGETS**, and open **Signing & Capabilities**.
5. Enable **Automatically manage signing**, choose your **Personal Team**, and give this target a unique bundle identifier, such as `com.yourname.MyHabitsPersonal`. If your team is missing, add your Apple Account under **Xcode → Settings → Accounts**. You do not need to configure the MyHabitsWidget target or any App Group for this scheme.
6. Enable **Settings → Privacy & Security → Developer Mode** on the phone and restart if requested. Press **⌘R** in Xcode to install and launch. If iOS asks you to trust the developer, follow the prompt under **Settings → General → VPN & Device Management**.

Free provisioning normally expires after **7 days**. Reconnect the phone and run the same scheme with the same team and bundle identifier to renew it. Reinstall over the existing app; do not delete it first. Keep exported backups, since uninstalling removes local data. Apple also limits free provisioning registrations and active development apps.

The personal and widget editions have separate app identities and databases. To transfer habits from a simulator or the widget edition, export a JSON backup there and import it in the personal app. Signing and actual installation must be verified in Xcode on your Mac; they have not been run in the Linux authoring environment.

## Open, sign and compile the widget edition in Xcode

1. Open `MyHabits.xcodeproj`. The project and shared scheme are checked in; no generator, CocoaPods or package installation is needed.
2. Select the **MyHabits** target → **Signing & Capabilities**. Choose your Apple development team and change the bundle identifier from `com.example.MyHabits` to a unique identifier, such as `com.yourname.MyHabits`.
3. Select **MyHabitsWidget**, choose the same team, and set its bundle identifier to the app identifier plus `.widget`. Configure the test target’s team/identifier too if requested.
4. Register a unique **App Group**, such as `group.com.yourname.MyHabits`. Enable exactly that group on **both** the app and widget targets in Signing & Capabilities. Replace `group.com.example.MyHabits` in all three places:
   - `Shared/SharedStore.swift`
   - `MyHabits/MyHabits.entitlements`
   - `MyHabitsWidget/MyHabitsWidget.entitlements`
5. Select the **MyHabits** scheme and an iOS 17+ simulator or attached iPhone. Choose **Product → Build** (⌘B), then Run (⌘R).

A development team with App Groups capability is required to install this shared-store/widget build on a physical phone. Personal Team provisioning may not support App Groups; in that case use an Apple Developer Program team. Never remove the shared-store entitlement to work around signing: the app deliberately reports a storage error rather than silently creating a separate widget-inaccessible database.

The target settings generate the application Info.plist; the extension supplies its WidgetKit extension declaration. There are no runtime API keys or environment variables. Both app targets include an opaque 1024 × 1024 app icon: a mint lightning bolt on charcoal, in `MyHabits/Assets.xcassets/AppIcon.appiconset`. Distribution screenshots are not included.

## Test

Run **Product → Test** (⌘U). `MyHabitsTests` covers reversible check-ins, new habits, a streak crossing an unfinished today, gaps/longest streaks, calendar day iteration, backup round-tripping/rejection, SwiftData persistence across contexts, reopening an on-disk store with its goal, goal progress before/at/beyond the target, goal backup/legacy import validation, reminder defaults/window validation, daily and weekly notification trigger generation, scheduling capacity, and reminder persistence/backup compatibility, and completion feedback lifecycle (expiry without data loss, rapid undo/recompletion, independent habits and background cleanup). Both shared schemes include their own test target; MyHabitsPersonalTests runs the same suite against the personal app module.

For the personal edition, select MyHabitsPersonal and use ⌘U on a simulator; in the commands below replace `-scheme MyHabits` with `-scheme MyHabitsPersonal`. On a Mac, the equivalent widget-edition commands are (substitute an installed simulator from `xcrun simctl list devices available`):

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
- Open New habit and verify six columns and four rows of swatches: red, blue, green, yellow, pink and purple from left to right, with four shades from deep to light. Confirm baby pink is available, selection marks contrast on deep shades, and previously saved colours stay unchanged when editing without selecting a new colour. Select each of the six new icons (meditation, yoga, basketball, skipping rope, pills and AirPods Max), save, relaunch and confirm its appearance in the list, details and widget. Check the grids on smaller screens and with VoiceOver.
- Before updating an existing installation, export a backup. Rebuild the app and widget together; the added goal field uses a stored default of 30 for automatic SwiftData migration. Confirm existing history, goal settings and archived habits remain. Goal-free habits are stored with a zero target without changing the existing SwiftData schema.
- Create and save a new habit with “Streak Goal” off: check that there is no target or progress bar, and the streak still increments. Enable a goal later, disable it again, and relaunch to verify history and the no-goal setting persist. Export/import that habit to verify it remains goal-free.
- Create a habit with a 7-day goal, edit it to 14, and relaunch to verify the goal persists. Check the card/detail counts before, at and beyond the goal; a missed day restarts progress without changing the longest streak. Export/import to verify goals are retained; backups from before goals were added import with a 30-day goal.
- On a physical iPhone, complete today from both the list and detail: expect one success haptic, top-to-bottom confetti, then the original icon after two seconds with the solid background remaining. Relaunch and verify completion stays saved without another celebration. Undo should immediately restore the subdued icon, with no success feedback. Complete two or three different habits about a second apart: earlier showers should keep falling while new ones begin at the top. Verify each shower ends independently. Rapidly complete/undo/recomplete to verify old timers do not clear newer feedback, and undo one habit while another shower is active to confirm only the first is cancelled. With Reduce Motion enabled, verify there are no moving particles; haptic availability follows the device/system settings. The simulator does not reproduce physical haptics.
- Check/uncheck today in both list and detail. Tap eligible past dates in the daily heatmap; future and pre-creation cells are disabled. Compare weekly totals, streaks and completion with the daily history.
- Check the dark theme in Home, detail, New/Edit Habit, Settings, sheets and widgets: charcoal backgrounds, lighter habit cards, subtle borders and neutral empty heatmap cells. Completed icons must retain their habit colour and readable tick. Confirm destructive buttons stay red and light mode retains its original native appearance.
- Create a habit with Reminders off and confirm no permission prompt. Enable it: confirm the initial time is 10:00 am, select a time a few minutes ahead and allow notifications. Background the app and lock a physical iPhone to verify delivery. Add two more times and verify a fourth cannot be added. Check selected weekdays vs Every day, a 10 am–6 pm window with three reminders (10 am, 2 pm, 6 pm), invalid/duplicate times, denied permission, and permission re-enabling in Settings. Rename/edit, archive/delete and disable reminders: check that obsolete future alerts are cancelled. Import a backup and verify schedules are restored when permission exists, with no automatic permission prompt during import.
- In Settings → Appearance, verify System is initially selected. Switch to Light and Dark and confirm the settings sheet, list, detail and editor update. Relaunch to check that the selection persists. Switch back to System and toggle the simulator’s appearance (Features → Toggle Appearance) to verify it follows the device.
- Test larger text, VoiceOver labels, and landscape. Dense heatmap cells are intentionally compact; VoiceOver names every date and state.
- Export a backup using Settings, save it in Files, modify a habit, then import the backup. Confirm matching history is restored and other habits remain. Import malformed JSON or an unsupported version: no data should change.
- Add the MyHabits Home Screen widget (long-press Home Screen → Edit/Add Widget → MyHabits). Toggle a habit there, reopen the app, and verify the same check-in; toggle in the app and verify the widget updates. Check small/medium/large layouts and archived habits disappearing. WidgetKit controls reload timing; midnight refresh is requested, not guaranteed to the second.
- Enable Airplane Mode and repeat create/check-in/reopen/export. No network connection is required. Files locations chosen for backup may themselves use iCloud; choose **On My iPhone** for a local-only backup.
- Change the system date/time zone only on a test device and check midnight behavior. The active app refreshes its date-dependent views every 30 seconds; widgets request a new timeline at midnight.

## Install the widget edition on a physical iPhone

Connect the phone to your Mac, unlock it, trust the Mac, and enable **Settings → Privacy & Security → Developer Mode** if prompted. Select it as the run destination, allow Xcode to register/provision it, and press ⌘R. If iOS asks, trust the developer under **Settings → General → VPN & Device Management**. Keep the app and widget in the same signed build. Installation needs Apple signing services; using the installed tracker does not.

For distribution use Xcode **Product → Archive** with a suitable distribution team, then Organizer → Distribute App (for example TestFlight or an eligible registered-device route). Developer builds can expire according to the provisioning profile; they are not permanent App Store installs.

## Data and streak rules

- Each habit is a daily habit. Reminder weekday selection affects notifications only; it does not change streak or completion-percentage rules. Reminders continue at their configured times even if the habit has already been completed that day.
- iOS allows 64 scheduled local notification requests per app. Every-day reminders use one slot per time; specific weekdays use one per selected weekday/time combination. The editor explains when a new enabled schedule would exceed this limit. A backup with more than 64 slots is retained, but alerts are paused until you reduce schedules; Settings explains the issue. Notification delivery depends on iOS permissions, Focus modes and local-time changes; no exact-to-the-second delivery guarantee is made. Time windows stay within a single day.
- One completion per local calendar date, stored as `yyyy-MM-dd` day keys. Historical keys do not move when travelling across time zones. The calendar follows the device settings.
- Current streak counts backwards from today if complete, otherwise yesterday; an incomplete today does not break yesterday’s streak until tomorrow. Longest streak scans history from the creation day through today.
- Completion = completed days ÷ elapsed calendar days from creation through today, rounded to the nearest percentage. Archiving retains history in local storage and exports but removes it from the app’s browsing and daily workflow. Settings can permanently clear archived data. A backup intentionally imported from before archiving can still restore that earlier state.
- Weekly columns follow the current locale’s first weekday. They show counts and intensity for the same 12 weeks as the daily heatmap.
- SwiftData uses an explicit shared on-device store with CloudKit disabled. There is no sync service. OS-level device backups are governed by iOS settings. Deleting the app may remove local data; export before uninstalling.
- JSON backups are unencrypted. Imports reject files above 20 MB as a safety limit; this is not a limit on the number of locally created habits.

## Source map

`Shared/`: SwiftData model, calendar/statistics helpers, App Group container and widget refresh marker. `MyHabits/`: SwiftUI list, creation, detail/history, statistics and backups. `MyHabits/ReminderEditor.swift` and `ReminderScheduler.swift`: reminder controls, validation and local notification scheduling. `Shared/HabitReminders.swift`: persisted reminder configuration. `MyHabitsWidget/`: timeline provider and interactive check-in App Intent. `MyHabitsTests/`: XCTest coverage.

`scripts/generate_project.py` regenerates the project with the Python standard library. It is optional and overwrites project settings; preserve your signing customisations before rerunning it. Future development should use this existing checkout; no separate Git worktree is required.

Language: Settings → Language offers English and Simplified Chinese (Mandarin). The choice is saved locally and changes the main interface immediately; user-written habit names/descriptions are preserved. Some operating-system messages and diagnostic errors follow iPhone settings or their original source language. Verify both languages on an iPhone, including reminders, dates, text clipping and switching with existing habits.

Reminder rotation: notification titles retain the habit name. Bodies cycle through 13 messages in chronological order across habits, using up to 64 non-repeating calendar notifications. Opening the app or changing reminders refreshes the rolling queue and advances the saved rotation past scheduled occurrences. iOS does not guarantee delivery timing/order under Focus modes. If all queued reminders elapse without reopening MyHabits, reminders pause until the app opens again. Validate rotation on a physical iPhone, including reopening between deliveries, simultaneous times, weekdays and daylight-saving changes.

Home layouts: use the layout menu in the bottom navigation bar to choose the original List, shorter full-width Cards with year-to-date heatmaps (one column per elapsed calendar week, including the current week), or a three-column Grid with current-month heatmaps. Selection is saved locally. Tap the habit icon to check in, and tap the name/heatmap for details. Card/grid context menus offer Archive and Delete, with confirmation. Edit uses the original list and reorder handles, returning to the selected layout on Done. Verify narrow-screen names, light/dark colors, large text, counters, completion feedback and scroll behavior on an iPhone.

Measure tracking: choose Yes/No, Counter or Measure when creating/editing. Measure supports a custom unit (up to 20 characters), a positive daily goal up to 1,000,000, and fractional totals. Enter total opens the amount editor; Add 1 increments until the goal, then opens the editor. Totals stop at the daily goal; lower totals undo completion. Daily values persist offline and in backups; earlier backups default to existing tracking behavior. Changing units relabels values and does not convert amounts.

Home progress: a Today/This week ring counts completed active habit-days (the current week through today, excluding days before a habit was created). The last check-in of the day shows a separate all-done card once per date; no extra shower is added. Completion status appears in list/cards/grid and details. Cancel in New/Edit Habit asks before discarding changes; swipe-to-dismiss is disabled while changes are pending. Goal changes remain available through the top-right edit icon; the redundant goal-edit row is removed.

Xcode validation for these additions: run tests for decimal completion/undo, measurement persistence and backups, year boundaries, and progress denominators. On a physical phone verify unit editing and decimal keyboards, both tap behaviors, cancel/keep editing/discard, daily/weekly ring updates and once-per-day celebrations, plus the book/pencil spacing in all layouts. Linux checks do not compile Apple frameworks or run these tests.
