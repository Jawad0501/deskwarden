# deskwarden

deskwarden is a macOS menu-bar program. It keeps the Mac awake for a live remote session. An armed desk covers every display after a physical touch. The owner removes the cover with Touch ID or the Mac password.

The program is for a person who runs coding agents and watches them through RustDesk. RustDesk needs an unlocked session. RustDesk needs a display that stays on.

## What the program does

The program holds the display awake. The program holds the system awake.

A hardware key, click, scroll, or pointer move covers the displays. The grace period is 3 seconds after Arm. The first hardware event is swallowed.

Input with a source process ID other than 0 stays on the real desktop. That test is for RustDesk and for agent input. A real RustDesk session has not proven this test yet.

The owner can play an alarm for 5 seconds. The owner can save one photo on this Mac. The owner can change the two lines on the cover.

## What the program does not do

The program does not use the network. The program does not log keystrokes. The program does not send telemetry. The program does not talk to RustDesk.

The program does not hide the camera light. The light stays on while Take a photo is enabled. Take a photo off stops the camera, so the light stays off.

## Soft lock

The cover is a soft lock. A reboot can bypass the cover. The power button can bypass the cover. Secure Input can bypass the cover.

Keep FileVault on. Keep a login password on. Use a strong RustDesk password. Use 2FA on the RustDesk account.

A later hardware key can still reach an app under the cover. A lid close sleeps the Mac. An attached external display is the exception.

## Permissions

Accessibility lets the event tap run. Input Monitoring lets the program receive keyboard events. Camera permission applies only when Take a photo is on.

Screen Recording belongs to RustDesk. This program does not request Screen Recording.

## Requirements

The Mac needs macOS 14 or later. The Mac needs Xcode. Command Line Tools alone cannot build the tests.

## Run the program

1. Clone this repository.
2. Open Terminal in the project folder.
3. Run the command below.
4. Grant Accessibility to the deskwarden program.
5. Grant Input Monitoring to the same program.
6. Allow the camera if you want photos.
7. Run the command again.
8. Choose Disarm before you type.
9. Choose Arm before you leave the Mac.

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run deskwarden
```

The built program is `.build/arm64-apple-macosx/debug/deskwarden` on an Apple silicon Mac. Grant the permissions to that program when macOS asks.

## Download

Release 1.0.0 includes a Mac app. The release page is https://github.com/Jawad0501/deskwarden/releases/tag/v1.0.0. The file name is `deskwarden-1.0.0-macos.zip`. The app runs on Apple silicon and on Intel. The Mac needs macOS 14 or later.

Apple did not notarize this build. macOS can report that Apple could not verify the app. The dialog can offer Move to Trash. Leave the app in place. The Open Anyway button appears after the first blocked open.

1. Download the zip from the Release page.
2. Open the zip.
3. Move Deskwarden.app to the Applications folder.
4. Open Deskwarden.app one time.
5. Choose Done in the warning dialog.
6. Leave the app out of the Trash.
7. Open System Settings.
8. Choose Privacy & Security.
9. Scroll to the Security section.
10. Choose Open Anyway next to the deskwarden message.
11. Confirm with Touch ID or the Mac password.
12. Open Deskwarden.app again.
13. Choose Open.
14. Grant Accessibility to deskwarden.
15. Grant Input Monitoring to deskwarden.
16. Allow the camera when you want photos.

## Settings

1. Choose Settings in the menu.
2. Set the alarm, the photo, and the two lines.
3. Choose Save.

The default lines are "The authorized person is out." and "Please wait." Choose Show captures to open the photo folder. The folder is `~/Library/Application Support/deskwarden/captures`.

## License

The license is MIT. The license text is in `LICENSE`.
