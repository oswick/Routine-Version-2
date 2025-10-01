## Mantener información de firma de tipos genéricos (GSON)
-keepattributes Signature
-keepattributes *Annotation*

## No ofuscar las clases del plugin de notificaciones
-keep class com.dexterous.flutterlocalnotifications.** { *; }

## Conservar TypeToken de GSON
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

## Si usas timezone (threeten)
-keep class org.threeten.** { *; }
-keep class com.github.threetenabp.** { *; }

# Flutter local notifications
-keep class com.dexterous.** { *; }

# Android Alarm Manager Plus
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
-keep class io.flutter.plugins.** { *; }

# Mantener tu implementación de callbacks
-keep class com.yourcompany.yourapp.** { *; }

# -----------------------------
# Google Play Services / Auth
# -----------------------------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.signin.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# -----------------------------
# Firebase (si lo usas)
# -----------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# -----------------------------
# Ignorar warnings innecesarios
# -----------------------------
-dontwarn sun.misc.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
