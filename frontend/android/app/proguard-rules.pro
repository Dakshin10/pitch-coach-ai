# Keep generic signatures used by Gson (flutter_local_notifications stores
# scheduled notifications as JSON and reads them back via reflection).
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }
