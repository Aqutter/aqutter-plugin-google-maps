import { callPlugin, defineAqutterNative, onPluginEvent } from '@aqutter/aqutter'
import type { AqutterNativeElement, PluginDefinition } from '@aqutter/aqutter'

/** 地圖相機位置。 */
export interface GoogleMapsCamera {
  lat: number
  lng: number
  zoom: number
}

/** 標記。`id` 省略時由原生端產生。 */
export interface GoogleMapsMarker {
  id?: string
  lat: number
  lng: number
  title?: string
}

export type GoogleMapsType = 'normal' | 'satellite' | 'terrain' | 'hybrid'

/** google-maps plugin 的契約。Dart 端 `GoogleMapsPlugin` 提供同名方法與事件。 */
export type GoogleMapsContract = PluginDefinition<
  {
    isSupported: { req: void, res: { supported: boolean } }
    getCamera: { req: void, res: GoogleMapsCamera }
    moveTo: { req: { lat: number, lng: number, zoom?: number, animate?: boolean }, res: { ok: boolean } }
    setMarkers: { req: { markers: GoogleMapsMarker[] }, res: { count: number } }
    setMapType: { req: { type: GoogleMapsType }, res: { type: string } }
  },
  {
    ready: { camera: GoogleMapsCamera }
    cameraIdle: GoogleMapsCamera
    tap: { lat: number, lng: number }
  }
>

declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'google-maps': GoogleMapsContract
  }
}

/** 與 Dart 端 `aqutterGoogleMapsSession` 一致。 */
export const GOOGLE_MAPS_SESSION = 'google-maps'

/** 網頁端 API。 */
export const googleMaps = {
  /** 註冊 `<aqutter-native>` 元素（冪等）；之後在頁面放 `<aqutter-native session="google-maps">` 即可。 */
  define: (): void => defineAqutterNative(),
  /** 目前平台是否有地圖（Android、iOS）。其他平台請改顯示替代內容。 */
  isSupported: async (): Promise<boolean> => (await callPlugin('google-maps', 'isSupported')).supported,
  getCamera: () => callPlugin('google-maps', 'getCamera'),
  /** 移動相機；`zoom` 省略時保持目前縮放。預設立即移動，`animate: true` 才做動畫（動畫要靠地圖持續繪圖）。 */
  moveTo: (lat: number, lng: number, options: { zoom?: number, animate?: boolean } = {}) =>
    callPlugin('google-maps', 'moveTo', { lat, lng, ...options }),
  /** 以這份清單取代全部標記。 */
  setMarkers: (markers: GoogleMapsMarker[]) => callPlugin('google-maps', 'setMarkers', { markers }),
  setMapType: (type: GoogleMapsType) => callPlugin('google-maps', 'setMapType', { type }),
  /** 地圖建立完成。 */
  onReady: (listener: (camera: GoogleMapsCamera) => void): (() => void) =>
    onPluginEvent('google-maps', 'ready', payload => listener(payload.camera)),
  /** 相機停止移動（拖曳、縮放或動畫結束）。 */
  onCameraIdle: (listener: (camera: GoogleMapsCamera) => void): (() => void) =>
    onPluginEvent('google-maps', 'cameraIdle', listener),
  /** 點擊地圖，回報點到的經緯度。 */
  onTap: (listener: (position: { lat: number, lng: number }) => void): (() => void) =>
    onPluginEvent('google-maps', 'tap', listener),
  /** 取得頁面上顯示地圖的 `<aqutter-native>` 元素。 */
  element: (root: ParentNode = document): AqutterNativeElement | null =>
    root.querySelector<AqutterNativeElement>(`aqutter-native[session="${GOOGLE_MAPS_SESSION}"]`),
}
