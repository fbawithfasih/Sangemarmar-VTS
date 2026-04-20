# Mobile App Setup

## 1. Initialise the Flutter project

Run this once from the `mobile/` directory to generate the native Android/iOS project files:

```bash
cd mobile
flutter create . --org com.sangemarmar --project-name sangemarmar_vts
flutter pub get
```

## 2. Android — file-save permissions

After `flutter create`, add these permissions to
`android/app/src/main/AndroidManifest.xml` inside the `<manifest>` tag,
**before** the `<application>` block:

```xml
<!-- Needed for open_filex + path_provider file downloads -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29" />
```

Android 10+ (API 29+) uses scoped storage — writing to the temp cache directory
(`getTemporaryDirectory`) does **not** require the write permission, so downloads
will work on modern devices without a runtime permission prompt.

## 3. iOS — no extra permissions needed

`open_filex` and `path_provider` work on iOS without additional `Info.plist` entries
for temp-directory file handling.

## 4. Run the app

```bash
# Make sure the backend is running first:
#   cd ../backend && npm run start:dev

flutter run
```

## 5. First login

Seed the backend database before logging in:

```bash
cd ../backend
npm run seed
```

Default credentials:
| Role           | Email                        | Password      |
|----------------|------------------------------|---------------|
| Admin          | admin@sangemarmar.com        | Admin@1234    |
| Manager        | manager@sangemarmar.com      | Manager@1234  |
| Gate Operator  | gate@sangemarmar.com         | Gate@1234     |
| Sales Staff    | sales@sangemarmar.com        | Sales@1234    |
| Cashier        | cashier@sangemarmar.com      | Cashier@1234  |
