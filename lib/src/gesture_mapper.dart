import 'dart:math' as math;

import 'package:aqutter/aqutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 把網頁傳來的語意手勢（`pan` / `pinch` / `doubleTap`）換成地圖的相機更新。
///
/// 純邏輯、不碰平台，所以能單元測試。地圖的 `scrollBy` 以地圖元件的邏輯像素為單位，
/// 網頁的位移是相對元素大小的 0..1 正規化值，因此要乘上地圖目前的大小。
class AqutterMapGestureMapper {
  double _zoomAtPinchStart = 0;

  /// 回傳該訊息對應的相機更新；不影響相機的訊息（`tap`、`longPress`…）回 null。
  ///
  /// [size] 是地圖元件的大小（邏輯像素）；[currentZoom] 是目前縮放（`pinch` 開始時記下）。
  CameraUpdate? update(AqutterNativeMessage message, {required AqutterMapSize size, required double currentZoom}) {
    switch (message.type) {
      case 'pan':
        if (message.data['phase'] != 'update') {
          return null;
        }
        final dx = (message.number('dx') ?? 0) * size.width;
        final dy = (message.number('dy') ?? 0) * size.height;
        // 手指往右拖，地圖內容跟著往右，相機目標反而往左
        return CameraUpdate.scrollBy(-dx, -dy);
      case 'pinch':
        final phase = message.data['phase'];
        if (phase == 'start') {
          _zoomAtPinchStart = currentZoom;
          return null;
        }
        if (phase != 'update') {
          return null;
        }
        final scale = message.number('scale') ?? 1;
        if (scale <= 0) {
          return null;
        }
        // 兩指距離加倍＝放大一級
        return CameraUpdate.zoomTo(_zoomAtPinchStart + math.log(scale) / math.ln2);
      case 'doubleTap':
        return CameraUpdate.zoomIn();
      default:
        return null;
    }
  }
}

/// 地圖元件的大小（邏輯像素）；用具名記錄而不是 Flutter 的 `Size`，測試不必依賴 UI 型別。
typedef AqutterMapSize = ({double width, double height});
