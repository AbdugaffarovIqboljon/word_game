# R8 / ProGuard keep rules for So'z Jangi release builds.
# Flutter itself ships default rules; these cover the native SDKs we added.

# Keep source/line info so Crashlytics stack traces are symbolicated.
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*

# Google Mobile Ads + UMP consent.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**

# Firebase (core / analytics / crashlytics / remote config).
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# in_app_purchase → Play Billing.
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# flutter_local_notifications (gson type tokens used by scheduled notifications).
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
