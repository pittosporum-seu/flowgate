# FlowGate Build Notes

FlowGate is built from v2rayNG with the Android VPN path intact. It uses Android `VpnService`, so the phone does not need a manual Wi-Fi or system proxy.

## Build on this PC

The global Gradle config at `C:\Users\13736\.gradle\gradle.properties` contains Maven proxy settings that return HTTP 405 for Google/Maven downloads. Use a project-specific Gradle home when building FlowGate:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = 'C:\Users\13736\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:GRADLE_USER_HOME = 'C:\Users\13736\.gradle-flowgate'
Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
.\gradlew.bat --no-daemon :app:assemblePlaystoreDebug
```

The Xray binding is stored at `app/libs/libv2ray.aar` from `AndroidLibXrayLite` tag `v26.5.9`. Do not delete it unless you plan to rebuild it with Go and gomobile.

## Current debug output

The latest v1.1 debug APKs are generated under:

```text
app/build/outputs/apk/playstore/debug/
```

For most Android phones, use `FlowGate_1.1.0_arm64-v8a.apk`. Use `FlowGate_1.1.0_universal.apk` only when you are unsure about the CPU architecture.
