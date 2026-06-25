# TicketToText — project notes

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

This device's UDID: `00008150-00042CA60C9A401C` (iPhone Mini / iPhone 17 Pro).

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

xcrun devicectl device install app --device 00008150-00042CA60C9A401C \
  build-device/Build/Products/Debug-iphoneos/TicketToText.app
```

### Notes
- `idevicesyslog`/`idevicecrashreport` (libimobiledevice) cannot pair with this
  iOS 27 device — use `devicectl` (CoreDevice) instead.
- The `log` device-streaming flags are unavailable on this macOS build; rely on
  the process list + `systemCrashLogs` copy for diagnosis.
- `build-device/` is gitignored (on-device build output).
