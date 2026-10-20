# R8 rules for release builds (Flutter's Gradle plugin adds this file).

# shared_preferences_android 2.5.0 talks to its Kotlin code through JNI
# (Pigeon JNI + package:jni): the Dart side looks classes, fields and
# methods up by their exact names and signatures, e.g.
#   getAll(Ljava/lang/String;Ljava/util/List;Lkotlin/coroutines/Continuation;)
# R8 cannot see those lookups. The plugin marks some of its classes with
# @Keep, but R8 still renamed or removed the Kotlin runtime classes below and
# some unannotated plugin classes, so release builds crashed on start
# (NoSuchMethodError / ClassNotFoundException; debug builds are not shrunk).
# Keep every class the Dart side looks up by name. The list comes from the
# class names in package:jni and shared_preferences_android's lib/ folders;
# CI checks it on every release APK (scripts/check_apk_jni_signatures.sh).

# Kotlin runtime used by the generated suspend-function glue.
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
-keep interface kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }

# The plugin's own API classes (registrars, data classes and their
# companions, enums, errors).
-keep class io.flutter.plugins.sharedpreferences.** { *; }
