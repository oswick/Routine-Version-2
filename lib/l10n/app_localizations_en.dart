// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Routine';

  @override
  String get calendar => 'Calendar';

  @override
  String get addEvent => 'Add Event';

  @override
  String get editEvent => 'Edit Event';

  @override
  String get deleteEvent => 'Delete Event';

  @override
  String get eventTitle => 'Event Title';

  @override
  String get eventDescription => 'Event Description';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get category => 'Category';

  @override
  String get importance => 'Importance';

  @override
  String get repeatDays => 'Repeat Days';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAll => 'Delete All';

  @override
  String get noEvents => 'No Events';

  @override
  String get todaysEvents => 'Today\'s Events';

  @override
  String get upcomingEvents => 'Upcoming Events';

  @override
  String get pastEvents => 'Past Events';

  @override
  String get earlierToday => 'Earlier Today';

  @override
  String get completed => 'Completed';

  @override
  String get notCompleted => 'Not Completed';

  @override
  String get markAsComplete => 'Mark as complete';

  @override
  String get markAsIncomplete => 'Mark as incomplete';

  @override
  String get deleteConfirmation =>
      'Do you want to delete this event? This action cannot be undone.';

  @override
  String get deleteConfirmationTitle => 'Delete Event';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sun => 'Sun';

  @override
  String get school => 'School';

  @override
  String get home => 'Home';

  @override
  String get work => 'Work';

  @override
  String get shopping => 'Shopping';

  @override
  String get health => 'Health';

  @override
  String get personal => 'Personal';

  @override
  String get low => 'Low';

  @override
  String get moderate => 'Moderate';

  @override
  String get important => 'Important';

  @override
  String get veryImportant => 'Very Important';

  @override
  String get none => 'None';

  @override
  String get authenticateToAccess => 'Authenticate to access the app';

  @override
  String get biometricNotAvailable =>
      'Biometric authentication is not available on this device.';

  @override
  String get deviceNotSupported =>
      'This device does not support biometric authentication.';

  @override
  String get noBiometricEnrolled =>
      'No biometric methods are enrolled on this device. Please set up fingerprint, face ID, or other biometric authentication in your device settings.';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get syncing => 'Syncing...';

  @override
  String get synced => 'Synced';

  @override
  String get error => 'Error';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get night => 'Night';

  @override
  String get noEventsForThisDay => 'No events for this day';

  @override
  String get tapPlusButtonToAddEvent =>
      'Tap the + button to add your first event';

  @override
  String get deleteAllDays => 'Delete All Days';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get signInToViewProfile => 'Sign in to view your profile';

  @override
  String get accessStatisticsAndSync =>
      'Access your statistics and sync your events across devices';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get startByCreatingFirstEvent =>
      'Start by creating your first event in the Home tab';

  @override
  String get areYouSureSignOut => 'Are you sure you want to sign out?';

  @override
  String get statistics => 'Statistics';

  @override
  String get events => 'events';

  @override
  String get totalTasks => 'Total Tasks';

  @override
  String get todayPending => 'Today Pending';

  @override
  String get incompleted => 'Incompleted';

  @override
  String get successRate => 'Success Rate';

  @override
  String get categories => 'Categories';

  @override
  String get security => 'Security';

  @override
  String get enableBiometricAuthentication => 'Enable Biometric Authentication';

  @override
  String get biometricNotAvailableDevice =>
      'Biometric authentication is not available on this device';

  @override
  String get appWillRequireBiometric =>
      'App will require biometric authentication on startup';

  @override
  String get biometricEnabledSuccessfully =>
      'Biometric authentication enabled successfully!';

  @override
  String get authenticationFailed => 'Authentication failed.';

  @override
  String get biometricDisabled => 'Biometric authentication disabled.';

  @override
  String get authRequiredToChangeSettings =>
      'Authentication required to change this setting.';

  @override
  String get autoLockTimeout => 'Auto-lock Timeout';

  @override
  String get currentlySetTo => 'Currently set to';

  @override
  String get overriddenByImmediateLock => '(overridden by immediate lock)';

  @override
  String get immediateLock => 'Immediate Lock';

  @override
  String get appLocksImmediately =>
      'App locks immediately when sent to background';

  @override
  String get appUsesTimeoutSetting =>
      'App uses timeout setting when sent to background';

  @override
  String get autoLockTimeoutSetTo => 'Auto-lock timeout set to';

  @override
  String get immediateEnabledMessage =>
      'Immediate lock enabled - app will lock when sent to background';

  @override
  String get immediateDisabledMessage =>
      'Immediate lock disabled - timeout will be used instead';

  @override
  String get securityOptions => 'Security Options';

  @override
  String get securityOptionsDescription =>
      '• Auto-lock Timeout: Sets how long the app stays unlocked after being sent to background\n• Immediate Lock: App locks immediately when minimized, regardless of timeout setting';

  @override
  String get biometricSetupMessage =>
      'To use biometric authentication, please ensure your device supports it and you have enrolled biometric credentials in your device settings.';

  @override
  String get immediately => 'Immediately';

  @override
  String get after1Minute => 'After 1 minute';

  @override
  String get after5Minutes => 'After 5 minutes';

  @override
  String get after15Minutes => 'After 15 minutes';

  @override
  String get after30Minutes => 'After 30 minutes';

  @override
  String get after1Hour => 'After 1 hour';

  @override
  String get never => 'Never';

  @override
  String get authenticationRequired => 'Authentication Required';

  @override
  String get authenticating => 'Authenticating...';

  @override
  String get authSuccessful => 'Authentication successful';

  @override
  String get authErrorOccurred => 'Authentication error occurred';

  @override
  String get newEvent => 'New Event';

  @override
  String get eventTitleRequired => 'Event Title *';

  @override
  String get whatNeedsToBeDone => 'What needs to be done?';

  @override
  String get description => 'Description';

  @override
  String get addSomeDetails => 'Add some details...';

  @override
  String get time => 'Time';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get notSet => 'Not set';

  @override
  String get date => 'Date';

  @override
  String get selectedDate => 'Selected Date';

  @override
  String get options => 'Options';

  @override
  String get repeat => 'Repeat';

  @override
  String get priority => 'Priority';

  @override
  String get createEvent => 'Create Event';

  @override
  String get updateEvent => 'Update Event';

  @override
  String get pleaseEnterTitle => 'Please enter a title for the event';

  @override
  String get endTimeAfterStart => 'End time must be after start time';

  @override
  String get errorSavingEvent => 'Error saving event';

  @override
  String get done => 'Done';

  @override
  String get priorityLevel => 'Priority Level';
}
