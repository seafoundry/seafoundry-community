## Flutter-specific ProGuard rules for release builds.

# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Google Maps
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

# Keep Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep Gson (used by Firebase)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Suppress warnings for common third-party libraries
-dontwarn com.google.android.play.core.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
