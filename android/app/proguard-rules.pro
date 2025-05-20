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
