# aqutter-plugin-google-maps

Aqutter plugin：把 `google_maps_flutter` 的地圖在 Flutter 裡渲染（墊在 WebView 之下），以 native view 鏡像顯示到網頁的 `<aqutter-native>` canvas。網頁因此能在地圖**之上**疊任何 HTML、做 z-index 與動畫；拖曳、縮放、點擊從網頁回傳，換成地圖的相機操作。

平台：Android、iOS。其他平台沒有地圖的原生實作，網頁以 `googleMaps.isSupported()` 得知並改顯示替代內容。

## 安裝

在 Aqutter 專案：

```bash
pnpm exec aqutter plugin add github:Aqutter/aqutter-plugin-google-maps
```

## 網頁端

```html
<div style="position: relative; height: 360px">
  <aqutter-native session="google-maps" fit="cover" style="position: absolute; inset: 0"></aqutter-native>
  <div class="overlay">任何 HTML 都可以疊在地圖上</div>
</div>
```

```ts
import { googleMaps } from 'aqutter-plugin-google-maps'

googleMaps.define()                               // 註冊 <aqutter-native>（冪等）
if (await googleMaps.isSupported()) {
  await googleMaps.moveTo(35.6762, 139.6503, { zoom: 11 })
  await googleMaps.setMarkers([{ id: 'tokyo', lat: 35.6762, lng: 139.6503, title: 'Tokyo' }])
  googleMaps.onTap(({ lat, lng }) => console.log('tapped', lat, lng))
  googleMaps.onCameraIdle(camera => console.log(camera))
}
```

| 方法 | 說明 |
|---|---|
| `isSupported()` | 目前平台是否有地圖 |
| `getCamera()` | 目前相機：`{ lat, lng, zoom }` |
| `moveTo(lat, lng, { zoom?, animate? })` | 移動相機；預設立即移動，`animate: true` 才做動畫 |
| `setMarkers(markers)` | 以這份清單取代全部標記 |
| `setMapType(type)` | `normal`／`satellite`／`terrain`／`hybrid` |
| `onReady` / `onCameraIdle` / `onTap` | 事件 |

操作：單指拖曳平移、雙指縮放、雙擊放大、單擊回報經緯度。

## 設定 Google Maps API key

沒有 key 時，Android 會顯示灰色空白地圖，iOS 會在建立地圖時出錯。key 由使用端 App 設定，**不要**把 key 寫進會提交的檔案。

1. 在 [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) 建立專案並啟用計費，啟用 **Maps SDK for Android** 與 **Maps SDK for iOS**，各建立一組 API key（建議分開，方便分別限制）。
2. 限制 key：Android key 限制「Android 應用程式」並填套件名稱與簽章指紋（SHA-1）；iOS key 限制「iOS 應用程式」並填 bundle ID。

### Android

`android/local.properties`（已被 git 忽略，不會提交）加一行：

```properties
GOOGLE_MAPS_API_KEY=你的 Android key
```

`android/app/build.gradle.kts` 最上面加 `import java.util.Properties`，並在 `defaultConfig` 區塊加上：

```kotlin
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
manifestPlaceholders["googleMapsApiKey"] = localProperties.getProperty("GOOGLE_MAPS_API_KEY", "NO_KEY")
```

`android/app/src/main/AndroidManifest.xml` 的 `<application>` 裡加上：

```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="${googleMapsApiKey}" />
```

### iOS

建立 `ios/Flutter/Secrets.xcconfig`（加進 `.gitignore`）：

```
GOOGLE_MAPS_API_KEY = 你的 iOS key
```

在 `ios/Flutter/Debug.xcconfig` 與 `ios/Flutter/Release.xcconfig` 各加一行：

```
#include? "Secrets.xcconfig"
```

`ios/Runner/Info.plist` 加上：

```xml
<key>GMSApiKey</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

`ios/Runner/AppDelegate.swift`：

```swift
import GoogleMaps
// …
override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  // 沒有設定 key 時用佔位值：地圖顯示灰色（授權失敗）但不會崩潰。
  // iOS 若完全沒呼叫 provideAPIKey，建立地圖時 App 會直接終止。
  let key = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String) ?? ""
  GMSServices.provideAPIKey(key.isEmpty ? "NO_KEY" : key)
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

`ios/Flutter/Secrets.xcconfig` 記得加進 `.gitignore`：

```
ios/Flutter/Secrets.xcconfig
```

## 運作方式與限制

- 擷取：Flutter 的 `RepaintBoundary.toImage` 抓不到地圖（鏡像會是透明的）。Android 直接擷取地圖內的 `TextureView`；iOS 用原生 `drawHierarchy` 擷取地圖 view。Android 地圖用 texture 模式（`useAndroidViewSurface = false`），本 plugin 會自動設定。
- 效能（Android 平板實測，滿版約 3200 像素寬）：約 15 fps，每幀約 10 MB。
- 輸入走網頁判斷的語意手勢（`input="gestures"`，預設），換成相機更新。iOS 的 PlatformView 不接受注入的 Flutter 指標事件，所以不用 `input="pointers"`。
- 擷取成本取決於地圖像素數；移動中的解析度預設是 `smooth`（固定在框架預設 `AqutterNative.defaultMinScale`（0.4），`GoogleMapsPlugin(quality:, minScale:)` 可調），停下來補完整解析度的定格幀。效能細節見 [aqutter_core 的 doc/nativeview.md](https://github.com/Aqutter/aqutter_core/blob/main/doc/nativeview.md)。
