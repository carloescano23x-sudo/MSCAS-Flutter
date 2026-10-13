# MSCAS Android + iOS project

This is a Flutter source project, not a converted APK. The iOS project includes privacy descriptions, a CocoaPods Podfile and a consistent bundle identifier (`com.mscas.attendance`).

## Android (Windows, macOS or Linux)

```sh
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. The existing Android Gradle file uses debug signing for release builds: configure production signing before distribution.

## iOS (Mac + Xcode required)

```sh
flutter pub get
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

In Xcode select Runner > Signing & Capabilities, choose your Apple development team, and confirm the bundle ID is available. To build for a connected device, run `flutter run` or use Xcode. For a distributable IPA, configure signing and run:

```sh
flutter build ipa --release
```

Output: `build/ios/ipa/`. An iOS build has NOT been executed or validated in this environment. Check `face_plugin` native iOS compatibility, Apple privacy declarations, Supabase OAuth redirect allowlist (`mscas://login-callback` if used), and permissions on a real iPhone. An IPA cannot be created directly from an APK.
