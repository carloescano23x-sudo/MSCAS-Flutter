# MSCAS Codemagic build instructions

This project contains two Codemagic workflows: `ios-compile-check` (unsigned, **cannot be installed on an iPhone**) and `android-apk` (Android release APK). These workflows test compilation; the iOS signing/distribution step must be configured using Apple Developer credentials.

1. Upload the contents of this folder to a **private GitHub repository**. Do not commit secret files, private keys, passwords, or `.env` files. Ensure `codemagic.yaml` is at repository root.
2. Open https://codemagic.io/, sign in, Add application, select GitHub repository, and choose `codemagic.yaml` configuration.
3. Run `ios-compile-check` first. If it fails, inspect the build log. A successful unsigned build does not prove device compatibility or enable installation.
4. To install on a physical iPhone, an active Apple Developer Program membership is required for Codemagic's normal signed iOS workflow. Configure the Developer Portal / App Store Connect integration and signing in Codemagic. For direct device installation, register the iPhone UDID and use Ad Hoc provisioning; for TestFlight, use App Store distribution and publish via App Store Connect. See https://docs.codemagic.io/flutter-code-signing/ios-code-signing/ and https://docs.codemagic.io/yaml-code-signing/signing-ios/.
5. After the unsigned build passes and Apple credentials are available, configure a **signed** iOS workflow using Codemagic's signing instructions. Do not attempt to install the unsigned Runner.app or rename an APK to IPA.

Potential issue: `face_plugin: ^0.0.4` may be Android-only or have other iOS build limitations. Confirm its iOS support in the cloud build log. The iOS build has not been executed here.
