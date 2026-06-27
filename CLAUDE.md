# TicketToText — project notes

## Standalone iMessage app structure (required for App Store / TestFlight)

The app ships as a **standalone iMessage application**: an icon-less,
launch-prohibited host whose only job is to carry the Messages extension. Getting
this wrong causes upload rejections **ITMS-90602** and **ITMS-90633** ("Invalid
Messages Application Support — MessagesApplicationSupport/MessagesApplicationStub
is missing while LSApplicationLaunchProhibited is true"). Hiding the home icon
with `LSApplicationLaunchProhibited` is only legal when the host is a real
messages-app stub; a normal app + the key is rejected.

What makes it a proper stub (all in `project.yml`, applied by `npm run ios:gen`):

- Host target `TicketToText` uses **`type: application.messages`** (product type
  `com.apple.product-type.application.messages`). That sets
  `PRODUCT_TYPE_HAS_STUB_BINARY=YES`, so Xcode uses Apple's
  `MessagesApplicationStub` as the app's main binary and adds the
  `MessagesApplicationSupport/MessagesApplicationStub` to the IPA at export time.
  Plain `application` does NOT do this — that was the original rejection.
- Host has **no source code** (the old `ios/App/TicketToTextApp.swift` is
  archived). A messages-app target must not compile its own executable.
- TWO icons, matching Apple's template: the **host** has a regular `AppIcon`
  asset catalog (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`) — this supplies
  `CFBundleIconName`, without which the upload fails **ITMS-90713**. The
  **extension** keeps the **iMessage App Icon** (`ASSETCATALOG_COMPILER_APPICON_NAME
  = "iMessage App Icon"`), the icon shown in the Messages drawer/store. Do NOT put
  the iMessage icon on the host — actool then mis-compiles it as a regular app icon.
- Because we use a hand-written `Info.plist` with `GENERATE_INFOPLIST_FILE=NO`,
  actool only writes the nested `CFBundleIcons` dict, not the **top-level**
  `CFBundleIconName` string that App Store validation checks. So `ios/App/Info.plist`
  sets `CFBundleIconName = AppIcon` explicitly (else ITMS-90713 even with the icon).
- Host needs an explicit scheme (`scheme:` block) because xcodegen no longer
  auto-generates one for the messages-app product type.
- `LSApplicationLaunchProhibited = true` stays in `ios/App/Info.plist` (now valid,
  because the stub is present → no home-screen icon).

Verify locally before any upload (no signing needed):
```
npm run ios:gen
xcodebuild -project TicketToText.xcodeproj -scheme TicketToText -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build-verify \
  CODE_SIGNING_ALLOWED=NO build
# Host .app should contain a ~68KB Mach-O stub named TicketToText (file <app>/TicketToText
# => "Mach-O 64-bit executable arm64"), Info.plist, PlugIns, and NO loose icon PNGs.
# Extension's Assets.car should list "iMessage App Icon".
```

## Distribution via TestFlight (paid Apple Developer account)

TestFlight builds are trusted automatically, so there's no 7-day expiry and no
device trust step (unlike free signing — see the white-screen section below).

This repo is wired for the paid account: `DEVELOPMENT_TEAM` and the
`com.sachinsagrawal.*` bundle IDs are set in `project.yml`. The account owner:

1. Register both App IDs (the MessagesExtension ID needs the Messages
   capability) and create the App Store Connect app record.
2. `npm run ios:gen` to regenerate `TicketToText.xcodeproj` (it's gitignored).
3. **Archive** the `TicketToText` scheme (Release) and upload to App Store Connect.
4. Answer the export-compliance question (No — only standard HTTPS), then enable
   TestFlight and add testers / turn on the public invite link.

### Who can play / what a non-tester sees
The game is turn-based and server-authoritative, so every player needs the app
installed. Each turn/invite is an `MSMessage`: the board-snapshot image and
caption are baked into the message layout and render for everyone, but the game
payload is a custom-scheme URL (`tickettotext://game?g=...`) only the extension
understands. A recipient without the app sees the bubble image + text but cannot
open or play it. On TestFlight (not the public App Store) the "get the app"
affordance leads nowhere usable, so **everyone in a game must be a TestFlight
tester** (install via the invite link, open TestFlight once).

### Server
The app targets the Vercel deployment in
`ios/MessagesExtension/Net/AppConfig.swift` (`serverBaseURL`). All testers' games
run through it, so that deployment must stay up. It is independent of the Apple
account and does not move with the app.

## On-device iMessage extension: white screen ("works in simulator, white on device")

### Symptom
The Messages app shows the Ticket to Text extension as a blank white panel on a
physical iPhone, while the same build runs correctly in the iOS Simulator.

### Root cause
The host app's `ios/App/Info.plist` sets `LSApplicationLaunchProhibited = true` to
hide the home-screen icon (iMessage-only app). With **free (Personal Team)
signing**, a developer certificate is only authorized on a device by *launching
the host app once* (the trust handshake; may also require Settings > General >
VPN & Device Management > Trust). `LSApplicationLaunchProhibited` makes the host
unlaunchable, so the cert is never trusted, so iOS silently refuses to launch the
embedded iMessage extension. The simulator has no trust requirement, so it never
shows the bug. The trust itself is per developer cert and persists once granted —
it's the unlaunchable host that blocks the *initial* grant, not the key per se.

### How to confirm (diagnosis)
With the white screen showing on the device, the extension process is absent and
there is no crash report:

```
# Extension NOT in the list while white = it is not launching (vs. a render bug)
xcrun devicectl device info processes --device <UDID> | grep -i MessagesExtension

# No crash .ips for our bundle = not a code crash, it's a launch/trust refusal
xcrun devicectl device copy from --device <UDID> \
  --domain-type systemCrashLogs --source . --destination ./crashlogs
grep -rIl 'com.cadenwarren.tickettotext' ./crashlogs   # (expect: nothing)
```

A genuine code crash would (a) appear briefly in the process list and (b) write
an `.ips`. Neither present ⇒ launch/trust problem, not a crash.

Test device UDID lives in `.env.local` (gitignored) as `DEVICE_UDID`; the
commands below use `<device-udid>` as a placeholder.

### Fix (recovery cycle)
Also required roughly every 7 days, whenever the free cert expires and the
extension goes white again:

1. Remove `LSApplicationLaunchProhibited` from `ios/App/Info.plist`.
2. `npm run ios:gen`, then build + install for device (commands below). A
   temporary home-screen icon appears.
3. On the phone: launch the "Ticket to Text" icon once. If prompted, trust the
   developer in Settings > General > VPN & Device Management.
4. Re-add `LSApplicationLaunchProhibited`, rebuild, reinstall. The icon
   disappears and the extension keeps working because the cert is now trusted.

### Device build + install commands
```
xcodebuild -project TicketToText.xcodeproj -scheme TicketToText \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build-device -allowProvisioningUpdates DEVELOPMENT_TEAM=ZRUFVD5GDT

xcrun devicectl device install app --device <device-udid> \
  build-device/Build/Products/Debug-iphoneos/TicketToText.app
```

### Notes
- `idevicesyslog`/`idevicecrashreport` (libimobiledevice) cannot pair with this
  iOS 27 device — use `devicectl` (CoreDevice) instead.
- The `log` device-streaming flags are unavailable on this macOS build; rely on
  the process list + `systemCrashLogs` copy for diagnosis.
- `build-device/` is gitignored (on-device build output).
