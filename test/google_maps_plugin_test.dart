import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_google_maps/aqutter_plugin_google_maps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

AqutterNativeMessage _message(String type, [Map<String, dynamic> data = const {}]) => AqutterNativeMessage(type, data);

void main() {
  const size = (width: 400.0, height: 200.0);

  group('gesture mapper', () {
    test('dragging right scrolls the camera left, scaled by the map size', () {
      final update = AqutterMapGestureMapper().update(
        _message('pan', {'phase': 'update', 'dx': 0.25, 'dy': -0.5}),
        size: size,
        currentZoom: 10,
      );
      // 0.25 × 400 = 100、-0.5 × 200 = -100；相機方向與手指相反
      expect(update!.toJson(), ['scrollBy', -100.0, 100.0]);
    });

    test('pan start and end do not move the camera', () {
      final mapper = AqutterMapGestureMapper();
      expect(mapper.update(_message('pan', {'phase': 'start'}), size: size, currentZoom: 10), isNull);
      expect(mapper.update(_message('pan', {'phase': 'end'}), size: size, currentZoom: 10), isNull);
    });

    test('pinch zooms one level when the finger distance doubles, relative to the zoom at pinch start', () {
      final mapper = AqutterMapGestureMapper();
      expect(mapper.update(_message('pinch', {'phase': 'start'}), size: size, currentZoom: 10), isNull);
      // 開始後相機縮放可能已被前一次更新改變；仍以 start 時記下的縮放為基準
      final update = mapper.update(_message('pinch', {'phase': 'update', 'scale': 2.0}), size: size, currentZoom: 11.3);
      expect(update!.toJson(), ['zoomTo', 11.0]);
    });

    test('pinching in zooms out and an invalid scale is ignored', () {
      final mapper = AqutterMapGestureMapper();
      mapper.update(_message('pinch', {'phase': 'start'}), size: size, currentZoom: 10);
      expect(mapper.update(_message('pinch', {'phase': 'update', 'scale': 0.5}), size: size, currentZoom: 10)!.toJson(), ['zoomTo', 9.0]);
      expect(mapper.update(_message('pinch', {'phase': 'update', 'scale': 0.0}), size: size, currentZoom: 10), isNull);
    });

    test('double tap zooms in; other gestures do not touch the camera', () {
      final mapper = AqutterMapGestureMapper();
      expect(mapper.update(_message('doubleTap'), size: size, currentZoom: 10)!.toJson(), ['zoomIn']);
      expect(mapper.update(_message('tap'), size: size, currentZoom: 10), isNull);
      expect(mapper.update(_message('longPress'), size: size, currentZoom: 10), isNull);
    });
  });

  group('plugin', () {
    test('id follows the naming rule and the session id matches the web element', () {
      expect(GoogleMapsPlugin().id, 'google-maps');
      expect(aqutterGoogleMapsSession, 'google-maps');
    });

    test('methods before the map exists report failure instead of throwing', () async {
      final plugin = GoogleMapsPlugin();
      expect(await plugin.handlers['moveTo']!({'lat': 25.0, 'lng': 121.5, 'zoom': 12}), {'ok': false});
      expect((await plugin.handlers['getCamera']!({}))['zoom'], isA<num>());
    });

    test('setMarkers keeps valid entries and drops malformed ones', () async {
      final plugin = GoogleMapsPlugin();
      final result = await plugin.handlers['setMarkers']!({
        'markers': [
          {'id': 'a', 'lat': 25.03, 'lng': 121.56, 'title': 'A'},
          {'id': 'bad', 'lat': 'x', 'lng': 1},
          {'lat': 24.1, 'lng': 120.6},
        ],
      });
      expect(result, {'count': 2});
    });

    test('setMapType maps names and falls back to normal', () async {
      final plugin = GoogleMapsPlugin();
      expect(await plugin.handlers['setMapType']!({'type': 'satellite'}), {'type': 'satellite'});
      expect(await plugin.handlers['setMapType']!({'type': 'unknown'}), {'type': 'normal'});
    });

    test('the underlay is skipped on platforms without a native implementation', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(GoogleMapsPlugin.isSupported, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(GoogleMapsPlugin.isSupported, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(GoogleMapsPlugin.isSupported, isTrue);
    });
  });
}
