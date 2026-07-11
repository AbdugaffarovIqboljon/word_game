# Data Safety / Privacy Labels — So'z Jangi

Exact answers for the **Google Play Data safety** form and the **Apple App
Privacy** nutrition labels, based on what the app actually does (Firebase
Analytics + Crashlytics + Remote Config, Google AdMob with UMP/ATT,
in_app_purchase, local shared_preferences; no accounts).

---

## Google Play — Data safety form

### Does your app collect or share any of the required user data types?
**Yes.**

### Is all user data encrypted in transit?
**Yes** (all third-party SDKs use HTTPS/TLS).

### Do you provide a way for users to request that their data be deleted?
**No account is created and identifiable data is not collected.** Local data is
removed by uninstalling. (Select "No"; explain in the privacy policy.)

### Data types — collected / shared / purpose

| Data type | Collected | Shared | Purpose | Processing |
|---|---|---|---|---|
| Device or other IDs (advertising ID) | Yes | Yes (Google AdMob + ad partners) | Advertising or marketing; Analytics | Not linked to identity; used for ads/tracking (consent-gated) |
| App activity — app interactions | Yes | No | Analytics; App functionality | Firebase Analytics; not linked to identity |
| App info & performance — crash logs | Yes | No | App functionality (diagnostics) | Firebase Crashlytics; not linked to identity |
| App info & performance — diagnostics | Yes | No | Analytics; App functionality | Firebase |
| Purchase history | Yes | No | App functionality (deliver purchases) | Store transaction only; no card data |

- **Not collected:** name, email, phone, address, location, contacts, photos/
  media, messages, files, calendar, health, financial/payment info (handled by
  the store), audio.
- **Advertising ID** declaration: the app uses an advertising ID (AdMob).
- **Account creation:** No.

---

## Apple — App Privacy (nutrition labels)

### Data Used to Track You  (linked to third-party data for tracking)
- **Identifiers → Device ID** (IDFA / advertising identifier) — AdMob.
  (Only when the user allows tracking via ATT + UMP.)
- **Usage Data → Product Interaction** — may be used by ad partners for
  measurement.

### Data Linked to You
- **None.** The app has no accounts and does not link data to a user identity.

### Data Not Linked to You
- **Identifiers → Device ID** — Third-Party Advertising, Analytics.
- **Usage Data → Product Interaction** — Analytics, App Functionality.
- **Diagnostics → Crash Data, Performance Data** — App Functionality.
- **Purchases → Purchase History** — App Functionality.

### Notes for the App Store submission
- `PrivacyInfo.xcprivacy` is bundled (declares tracking = true, AdMob tracking
  domains, the UserDefaults required-reason API `CA92.1`, and the collected data
  types above). Ensure it is added to the Runner target's *Copy Bundle Resources*.
- `NSUserTrackingUsageDescription` is set in Info.plist; the ATT prompt is driven
  by the Google UMP flow at first launch.
- SKAdNetworkItems for AdMob are present in Info.plist (paste Google's full,
  current identifier list before release).

---

## Consistency checklist
- Privacy policy URL set in both stores → `docs/store/privacy_policy.md` (host it).
- AdMob personalized ads gated behind UMP consent (+ ATT on iOS).
- No login / no PII collected → both forms reflect "no account", "not linked".
- remove-ads purchase disables interstitials (does not change data collection).
