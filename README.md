# Jumpz

Jumpz is a gamified alarm app that motivates you to wake up and get moving. You
can schedule a daily alarm at your preferred wake‑up time and set a goal for
the number of jumps you need to complete to dismiss the alarm. The app tracks
your jump sessions using the device's accelerometer and stores your progress in
Firebase. See how you compare to others on the leaderboard and watch your
improvement over time via the built‑in graph.

## Features

* **Firebase Authentication** – Users sign up or sign in with their email and password.
  The Firebase Authentication service provides a secure, multi‑platform identity
  solution that supports email and password accounts as well as other providers
  【134410021290718†L151-L164】.
* **Cloud Firestore** – User profiles and jump sessions are stored in Cloud
  Firestore. Firestore synchronises data in realtime across devices and
  provides offline support, so your progress is preserved even without an
  internet connection【833088903653266†L1417-L1443】.
* **Local Notifications** – Alarms are scheduled using the
  `flutter_local_notifications` plugin. The plugin supports scheduling
  notifications to appear daily at a specified time【745656195084809†L141-L149】.
  When the notification is tapped, the app launches a jump session.
* **Accelerometer Jump Counting** – Jump sessions use the device's
  accelerometer via the `sensors_plus` package to estimate the number of jumps
  performed. A simple peak detection algorithm counts each jump when the
  acceleration magnitude crosses a threshold【250786208032889†L165-L173】.
* **Progress Graph** – A line chart shows your recent jump sessions using the
  `fl_chart` package. FL Chart is a highly customizable Flutter chart library
  that supports various chart types including line charts【131649738585040†L48-L50】.
* **Leaderboard** – A realtime leaderboard displays the top users ranked by
  total jumps. Data updates automatically when new sessions are recorded.

## Getting Started

1. Install the [Flutter SDK](https://flutter.dev/docs/get-started/install) and
   ensure you can run Flutter apps on your target platforms.
2. Clone this repository or extract the ZIP archive provided. Run
   `flutter pub get` in the project directory to install dependencies.
3. Create a Firebase project in the [Firebase console](https://console.firebase.google.com/).
   Follow the official FlutterFire documentation to add Firebase to your
   Android and iOS apps. You will need to download and place `google-services.json`
   (Android) and `GoogleService-Info.plist` (iOS) files in the respective
   platform directories. Refer to the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli)
   for an automated setup.
4. Enable **Email/Password** authentication in the Firebase console. Create
   indexes for `users.totalJumps` if required by Firestore queries.
5. Run the app with `flutter run` on your device or simulator. Sign up, set
   your alarm and jump goal, and start jumping!

## Notes

* The accelerometer jump counting algorithm is simplistic and may not produce
  perfect results. Feel free to tune the `_jumpThreshold` value in
  `lib/services/jump_counter_service.dart` or implement a more sophisticated
  algorithm for better accuracy.
* Scheduled notifications may behave differently on various devices due to
  manufacturer battery optimisations. Users may need to disable battery
  optimisation for the app to ensure alarms fire reliably【745656195084809†L230-L240】.
* To fully rebuild the Android and iOS project folders, run `flutter create .`
  in the root of the project. This command will generate any missing platform
  files while preserving your existing Dart code.
