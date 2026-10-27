import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// Where the install id is kept: on Android, a preferences file of its own,
/// `io.getstream.ai.client-id.xml`, so an app's backup rules can exclude
/// exactly that file. Other platforms use their default store.
const SharedPreferencesOptions kAIInstallIdPreferencesOptions = SharedPreferencesAsyncAndroidOptions(
  backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
  originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(fileName: 'io.getstream.ai.client-id'),
);
