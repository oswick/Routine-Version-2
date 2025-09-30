# My-App (Android)

My-App is a productivity and event management application for Android, built with Flutter. It helps you organize your time, keep your data secure, and stay synchronized.

## Key Features

*   **Event Management:** Create, view, and manage your events in a calendar or daily view.
*   **Pomodoro Timer:** Improve your focus and productivity with a built-in Pomodoro timer.
*   **Advanced Security:** Protect your app with biometric authentication (fingerprint or Face ID) and auto-lock settings.
*   **Social Login:** Quickly sign in with your Google account.
*   **Automatic Synchronization:** Keep your data synchronized across devices. The app works both online and offline.
*   **Personalization:** Configure the app to your liking, including language and security options.
*   **Push Notifications:** Get timely reminders for your events.
*   **Background Services:** The app can run tasks in the background to keep your data up-to-date.

## Security

The application offers several layers of security to protect your information:

*   **Biometric Authentication:** Enable access via fingerprint or Face ID for enhanced security. You can activate this option in the settings screen.
*   **Auto-Lock:** Set a timeout for the app to automatically lock after being in the background.
*   **Immediate Lock:** Override the timeout and have the app lock immediately upon being minimized.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Dependencies

This project uses the following key dependencies:

*   **`supabase_flutter`**: For backend services and database.
*   **`google_sign_in`**: For Google authentication.
*   **`firebase_core`**, **`firebase_crashlytics`**, **`firebase_analytics`**: For Firebase integration, crash reporting, and analytics.
*   **`local_auth`**: For biometric authentication.
*   **`table_calendar`**: For the calendar view.
*   **`provider`**: For state management.
*   **`flutter_local_notifications`**: For local notifications.
*   **`workmanager`**, **`android_alarm_manager_plus`**: For background tasks and alarms.
*   **`hive_flutter`**: For local storage.
*   **`connectivity_plus`**: To check network connectivity.

And many more. Check the `pubspec.yaml` file for a full list of dependencies.