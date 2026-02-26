# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Flutter uses Play Core for deferred components (dynamic feature modules).
# This app does not use them — suppress R8 warnings about missing stubs.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
