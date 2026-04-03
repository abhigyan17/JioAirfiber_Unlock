# Patched APK Package

This folder contains the final patched APK files for JioHomeJFE along with instructions for installing and running the application on an Android device or emulator.

## Installation Instructions

1. Enable Unknown Sources / ADB Debugging
   - On your Android device, go to **Settings > Security** and enable **Install unknown apps** for the file manager or browser you will use.
   - For emulators (e.g., Nox), ensure ADB debugging is enabled.

2. Install via ADB (recommended)
   ```bash
   adb install Patched_APK/JioHomeJFE_patched_v2-aligned-debugSigned.apk
   # or, if you prefer the unsigned version (requires a rooted/emulated device)
   # adb install Patched_APK/JioHomeJFE_patched_unsigned.apk
   ```
   This will install the patched application on the device.

3. Install via Direct Transfer
   - Copy the desired `.apk` file to your device.
   - Open the file using a file manager and tap **Install**.

## Running the App

After installation, launch the app from the app drawer. The patched version bypasses the login screen and launches directly into the custom launcher.

## Screenshots

![Splash Screen](../splash.png)

![Main Activity](../main.png)

## Social Links

- YouTube Channel: https://www.youtube.com/@its-htz
- Discord Server: https://discord.gg/Pk473Ccyw

---
*Generated automatically by the testing workflow.*
