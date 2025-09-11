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

# Keep HTTP and networking classes
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep JSON serialization classes
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.stream.** { *; }

# Keep model classes that are serialized/deserialized
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep all classes in your app package
-keep class com.eisenvault.** { *; }

# Keep Flutter plugin classes
-keep class io.flutter.plugins.** { *; }

# Keep method channel classes
-keep class * extends io.flutter.plugin.common.MethodChannel { *; }
-keep class * extends io.flutter.plugin.common.EventChannel { *; }

# Keep HTTP client classes
-keep class java.net.** { *; }
-keep class javax.net.** { *; }

# Keep SSL/TLS classes
-keep class javax.net.ssl.** { *; }
-keep class java.security.** { *; }

# Keep reflection-based classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep class * extends java.lang.Exception { *; }
