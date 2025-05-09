# Flutter wrapper and embedding classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Keep your application classes (replace with your actual package name)
-keep class com.eisenvault.eisenvaultappflutter.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep R classes (resource classes)
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep Play Core classes used by Flutter deferred components
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep annotations used by some libraries (e.g., Tink, errorprone)
-keep class javax.annotation.** { *; }
-dontwarn javax.annotation.**

-keep class com.google.errorprone.annotations.** { *; }
-dontwarn com.google.errorprone.annotations.**
