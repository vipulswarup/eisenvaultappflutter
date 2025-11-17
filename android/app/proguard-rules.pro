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

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# SQLite
-keep class io.flutter.plugins.flutter.db.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# Device Info Plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-dontwarn dev.fluttercommunity.plus.device_info.**

# Package Info Plus
-keep class io.flutter.plugins.packageinfo.** { *; }
-dontwarn io.flutter.plugins.packageinfo.**

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# File Selector
-keep class io.flutter.plugins.file_selector.** { *; }
-dontwarn io.flutter.plugins.file_selector.**

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# AIO Scanner
-keep class com.aio_scanner.** { *; }
-dontwarn com.aio_scanner.**

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# Open File
-keep class com.crazecoder.openfile.** { *; }
-dontwarn com.crazecoder.openfile.**

# Printing
-keep class net.nfet.printing.** { *; }
-dontwarn net.nfet.printing.**

# Syncfusion Flutter plugins
-keep class com.syncfusion.flutter.** { *; }
-dontwarn com.syncfusion.flutter.**

# Dio HTTP client
-keep class dio.** { *; }
-dontwarn dio.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# HTTP package
-keep class io.flutter.plugins.connectivity.** { *; }
-dontwarn io.flutter.plugins.connectivity.**

# Kotlin coroutines (used by many plugins)
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-keepclassmembers class kotlin.coroutines.SafeContinuation {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# Keep Kotlin metadata
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Keep native method implementations
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep classes with @Keep annotation
-keep @androidx.annotation.Keep class *
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Keep all classes in plugin packages that might use reflection
-keep class io.flutter.plugins.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.baseflow.** { *; }
-keep class com.tekartik.** { *; }
-keep class com.it_nomads.** { *; }
-keep class com.crazecoder.** { *; }
-keep class net.nfet.** { *; }
-keep class com.syncfusion.** { *; }
-keep class com.aio_scanner.** { *; }
