# Ktor server rules for Android
# Ktor references java.lang.management and SLF4J which don't exist on Android

-dontwarn java.lang.management.**
-dontwarn org.slf4j.**
-dontwarn io.ktor.util.debug.**
-dontwarn kotlinx.coroutines.debug.**

# Keep serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

-keep,includedescriptorclasses class com.njl.flowgate.server.dto.**$$serializer { *; }
-keepclassmembers class com.njl.flowgate.server.dto.** {
    *** Companion;
}
-keepclasseswithmembers class com.njl.flowgate.server.dto.** {
    kotlinx.serialization.KSerializer serializer(...);
}
