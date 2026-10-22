# Tasks for 2610221548

## Phase 1 — 前置（需 aqutter 的 supportedPlatforms 已可用）
- [ ] 確認殼 `supportedPlatforms` 已合併並可取用（`pubspec.yaml` 的殼 ref）

## Phase 2 — Dart 端
- [ ] `GoogleMapsPlugin.supportedPlatforms => {android, iOS}`；整理 `isSupported`
- [ ] `test/google_maps_plugin_test.dart`

## Phase 3 — 網頁端
- [ ] `view.ts`：`GoogleMapsView` 介面
- [ ] `nativeProvider.ts`：原生（鏡像）實作
- [ ] `loadGoogleMaps.ts`：腳本載入器（key、逾時、重複載入）
- [ ] `jsProvider.ts`：JS 實作（相機、標記、地圖類型、事件）
- [ ] `index.ts`：`configure`、`provider`、`mount`，移除頂層方法
- [ ] TS 單元測試

## Phase 4 — 文件與驗證
- [ ] README（含 key、CSP、referrer 的實測結果）
- [ ] `pnpm typecheck`、TS 測試、`flutter test`
- [ ] 在非原生平台（Windows）實際載入 JS 地圖並確認 mount、移動、標記、點擊事件（需要使用者提供 JS API key）
