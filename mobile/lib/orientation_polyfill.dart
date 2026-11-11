/// Android WebView only fires `deviceorientation` on secure (https) pages, so
/// the VR explorer served over plain http on the LAN only responds to touch.
///
/// MainActivity streams the phone's rotation sensor as W3C angles; WebScreen
/// forwards each reading to `window.__vnOrient`, which dispatches a synthetic
/// `deviceorientation` event — exactly what A-Frame's magic-window
/// look-controls listen for. If the page ever receives real sensor events
/// (e.g. served over https) the shim stands down.
const String kOrientationPolyfillJs = r'''
(function () {
  if (window.__vnOrient) return;
  var real = false;
  window.addEventListener('deviceorientation', function (e) {
    if (!e.__vn && e.alpha != null) real = true;
  }, true);
  window.__vnOrient = function (a, b, g) {
    if (real) return;
    var e = new Event('deviceorientation');
    e.alpha = a; e.beta = b; e.gamma = g; e.absolute = false; e.__vn = true;
    window.dispatchEvent(e);
  };
  // Motion now works without https, so A-Frame's "access over HTTPS" notice
  // is misleading inside the app. Hide the whole modal: `.a-modal` is a
  // full-screen 60%-black backdrop above everything — hiding only the inner
  // `.a-dialog` leaves it dimming the scene and swallowing every tap.
  var hide = function () {
    if (!document.head) return setTimeout(hide, 50);
    var s = document.createElement('style');
    s.textContent = '.a-modal{display:none!important}';
    document.head.appendChild(s);
  };
  hide();
})();
''';
