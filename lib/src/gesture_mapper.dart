import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:aqutter/aqutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 把網頁傳來的語意手勢（`pan` / `pinch` / `doubleTap`）換成地圖的相機更新。
///
/// 純邏輯、不碰平台，所以能單元測試。座標單位：地圖的 `scrollBy` 與 `zoomBy` 的焦點都以地圖元件的邏輯像素為單位，
/// 網頁的位移與位置是相對元素大小的 0..1 正規化值，因此要乘上地圖目前的大小。
///
/// 縮放用**增量**（`zoomBy`）並帶焦點，不用絕對值（`zoomTo`）：
/// - `zoomTo` 永遠繞著地圖中心縮放，兩指中心的地理位置會跑掉（「在錯的點展開」）；
/// - 絕對值需要知道目前的縮放，那個值來自相機回呼、是非同步更新的，一旦不同步，下一次縮放就以錯的基準計算。
class AqutterMapGestureMapper {
  double _lastScale = 1;
  Offset? _lastFocal;

  /// 回傳該訊息對應的相機更新（依序套用）；不影響相機的訊息（`tap`、`longPress`…）回空清單。
  List<CameraUpdate> update(AqutterNativeMessage message, {required AqutterMapSize size}) {
    switch (message.type) {
      case 'pan':
        if (message.data['phase'] != 'update') {
          return const [];
        }
        final dx = (message.number('dx') ?? 0) * size.width;
        final dy = (message.number('dy') ?? 0) * size.height;
        // 手指往右拖，地圖內容跟著往右，相機目標反而往左
        return [CameraUpdate.scrollBy(-dx, -dy)];
      case 'pinch':
        return _pinch(message, size);
      case 'doubleTap':
        // 以點到的位置為焦點放大一級（沒有位置就繞中心）
        final x = message.number('x');
        final y = message.number('y');
        return [
          if (x != null && y != null) CameraUpdate.zoomBy(1, Offset(x * size.width, y * size.height)) else CameraUpdate.zoomIn(),
        ];
      default:
        return const [];
    }
  }

  List<CameraUpdate> _pinch(AqutterNativeMessage message, AqutterMapSize size) {
    final phase = message.data['phase'];
    final x = message.number('x');
    final y = message.number('y');
    final focal = x != null && y != null ? Offset(x * size.width, y * size.height) : null;
    if (phase == 'start') {
      _lastScale = 1;
      _lastFocal = focal;
      return const [];
    }
    if (phase != 'update') {
      _lastFocal = null;
      return const [];
    }
    final scale = message.number('scale') ?? 1;
    if (scale <= 0) {
      return const [];
    }
    // 網頁送的是自 pinch 開始的累計倍率；換成這一次相對上一次的增量（兩指距離加倍＝放大一級）
    final amount = math.log(scale / _lastScale) / math.ln2;
    _lastScale = scale;
    final updates = <CameraUpdate>[];
    final previousFocal = _lastFocal;
    _lastFocal = focal;
    if (amount.abs() > 1e-6) {
      updates.add(focal != null ? CameraUpdate.zoomBy(amount, focal) : CameraUpdate.zoomBy(amount));
    }
    // 兩指中心移動＝平移（與單指拖曳同向）
    if (previousFocal != null && focal != null) {
      final move = focal - previousFocal;
      if (move.distance > 1e-6) {
        updates.add(CameraUpdate.scrollBy(-move.dx, -move.dy));
      }
    }
    return updates;
  }
}

/// 地圖元件的大小（邏輯像素）；用具名記錄而不是 Flutter 的 `Size`，測試不必依賴 UI 型別。
typedef AqutterMapSize = ({double width, double height});
