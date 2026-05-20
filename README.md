# Health Sync

A private, local-only way to view Apple Health on your Apple TV. The iPhone reads
HealthKit and pushes a snapshot directly to a paired Apple TV over an encrypted
peer-to-peer connection on your home network. Nothing touches a server.

## Architecture

```
┌──────────────────┐        Apple Application Service        ┌──────────────────┐
│ HealthSyncPhone  │  com.healthsync.local (encrypted P2P)   │  HealthSyncTV    │
│  iOS app         │ ◀─────────────────────────────────────▶ │  tvOS app        │
│                  │                                          │                  │
│ • HealthKit      │  SnapshotRequest →                       │ • DDDevicePicker │
│ • NWListener     │  ← SyncEnvelope (Codable, length-framed) │ • NWConnection   │
└──────────────────┘                                          │ • SwiftUI + Charts│
                                                              └──────────────────┘
```

* **DeviceDiscoveryUI** (`DDDevicePickerViewController`) on tvOS lets the user pick
  a nearby iPhone signed into the same iCloud account.
* **Network framework** (`NWListener` / `NWConnection`) with
  `NWParameters.applicationService` carries the connection. The transport is
  encrypted and authenticated by the OS; no certificates to manage.
* **HealthSyncShared** is a Swift package containing the wire protocol (`SyncEnvelope`,
  `HealthSnapshot`, etc.) and length-prefixed framing. Both apps depend on it so
  the schema can't drift.

## Repo layout

```
Shared/                       # Swift package shared by both apps
  Package.swift
  Sources/HealthSyncShared/
    ServiceIdentifier.swift
    WireProtocol.swift
    MessageFraming.swift

iOS/HealthSyncPhone/          # iPhone "sender" app
  HealthSyncPhoneApp.swift
  Views/
  Services/                   # HealthKitReader, PhoneSyncService, SleepNightAssembler
  SupportingFiles/            # Info.plist, entitlements

tvOS/HealthSyncTV/            # Apple TV "receiver" app
  HealthSyncTVApp.swift
  Views/
    Pairing/                  # DDDevicePicker host
    Dashboards/               # Activity, Heart, Sleep, Workouts
  Services/                   # PhoneConnection, HealthSnapshotStore
  SupportingFiles/
```

## Wiring it up in Xcode (one-time)

The source files are here; the `.xcodeproj` is not (Xcode project files don't
diff cleanly from a Linux container). Create the workspace once:

1. **New Xcode workspace** at the repo root: `HealthSync.xcworkspace`.
2. **Add the shared package**: File → Add Package Dependencies → "Add Local…" → select `Shared/`.
3. **Create the iOS target**: File → New → Project → iOS → App
   * Product: `HealthSyncPhone`
   * Interface: SwiftUI · Language: Swift · Minimum deployment: iOS 19.0
   * Delete the generated `ContentView.swift` / `HealthSyncPhoneApp.swift`.
   * Drag in everything under `iOS/HealthSyncPhone/` (use "Create groups", don't copy).
   * In target settings:
     * Replace `Info.plist` with `iOS/HealthSyncPhone/SupportingFiles/Info.plist`.
     * Code Signing → Entitlements → `iOS/HealthSyncPhone/SupportingFiles/HealthSyncPhone.entitlements`.
     * Frameworks & Libraries → add `HealthSyncShared`.
     * Signing & Capabilities → add **HealthKit**.
4. **Create the tvOS target**: File → New → Target → tvOS → App
   * Product: `HealthSyncTV`, deployment tvOS 19.0.
   * Same drag-in pattern with files under `tvOS/HealthSyncTV/`.
   * Use the tvOS `Info.plist` and entitlements from `SupportingFiles/`.
   * Frameworks: `HealthSyncShared`, `DeviceDiscoveryUI`.
5. **Bundle IDs**: pick something like `com.yourname.healthsync.phone` and
   `com.yourname.healthsync.tv`. The `NSApplicationServiceIdentifier`
   (`com.healthsync.local`) is shared between the two apps; **don't** change it
   on only one side.
6. **Same Apple ID / development team** for both targets — the OS uses the team
   identity to authorize the peer-to-peer link.

## First run

1. Install the iOS app on your phone; grant Health and Local Network permissions
   when prompted.
2. Install the tvOS app on Apple TV (sign into the same iCloud account).
3. On Apple TV, tap **Find iPhone**. The picker shows nearby devices on your
   iCloud account that advertise `com.healthsync.local`.
4. Pick your phone. The OS shows a one-time confirmation on each device.
5. The TV requests a snapshot; the phone pushes back a `SyncEnvelope`.

Subsequent launches re-use the saved pairing automatically (stored as a
`UserDefaults` key on the TV); the OS handles re-establishing the encrypted
channel.

## Known gotchas

* **Background limits on iOS.** The phone can't push 24/7 from a locked pocket.
  Snapshots happen when the iPhone app is foreground or during the system's
  background processing windows. The current code is request/response —
  the TV asks, the phone answers. Good enough for opening the dashboard in the
  evening; for live workout streaming you'd want a BGProcessingTask.
* **Apple TV cache eviction.** tvOS will purge the caches directory when storage
  is tight. `HealthSnapshotStore` writes there, so if the cache is gone we just
  fetch a fresh snapshot. Don't move the cache to the documents directory —
  tvOS doesn't promise persistence there either; rely on a fresh sync.
* **Same iCloud account.** DeviceDiscoveryUI's picker is scoped to the local
  iCloud / iCloud Family devices. Two devices on the same Wi-Fi but different
  iCloud accounts won't see each other.
* **Local Network prompt.** Even with the application-service plumbing, iOS will
  show a "wants to find devices on your local network" prompt the first time
  the apps talk. The `NSLocalNetworkUsageDescription` strings live in both
  `Info.plist` files.
* **HealthKit on the iPhone only.** The tvOS app does **not** link HealthKit and
  doesn't ask for any health permissions on the TV side — it never reads from
  Health directly; the phone is the sole source of truth.

## Things deliberately left out (v1)

* No iCloud sync, no CloudKit, no server. By design.
* No watchOS companion. Heart-rate-during-workouts streaming would belong there.
* No widgets / Apple TV top shelf. Easy to add later.
* No unit tests yet. `SleepNightAssembler` and `LengthPrefixedFraming` are the
  obvious first targets when you do.

## License

TBD — pick something before publishing.
