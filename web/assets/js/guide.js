/* ==========================================================================
   VIRASAT GUIDE — the animated guide, on every page
   --------------------------------------------------------------------------
   The Explore page has always had the guide character with a rich, city-aware
   script of its own. This is the lightweight companion for the rest of the
   app: the female guide appears on each page, and the moment a page opens
   she switches topic and explains what that page is for. On the home page
   she also follows the feature slides as they scroll into view, introducing
   each one in turn.

   Speech: the neural voice through the local proxy (/api/speech) when it is
   running, otherwise the best Indian-English browser voice. Muting persists.
   Explore and VR keep their own guides and are skipped here.
   ========================================================================== */
(function () {
  'use strict';

  var page = (window.location.pathname.split('/').pop() || 'index.html').toLowerCase();
  if (page === '' || page === '/') page = 'index.html';
  if (page === 'explore.html' || page === 'vr.html') return;   // they have their own

  var IMG = 'assets/images/guide/';

  /* Inside the Android app (WebView user agent carries "VirasatApp") the
     guide waits to be asked: no intro on page load, and nothing until the
     visitor taps her — then she explains the page's feature. */
  var IN_APP = /VirasatApp/i.test(navigator.userAgent || '');

  /* The app-wide guide is the female character (her voice is female); the
     Explore page keeps the original male guide, which has the male voice.
     Drop her artwork at assets/images/guide/female_guide.png — a single
     "presenting" pose reads well for every script. If the file is missing
     the <img> onerror below falls back to the male character so the guide
     never renders broken. */
  var FEMALE = IMG + 'female_guide_sm.webp';
  var FALLBACK = IMG + 'guide_character_sm.webp';
  var POSE = {
    welcome:    FEMALE,
    explaining: FEMALE,
    pointing:   FEMALE,
    excited:    FEMALE,
    photo:      FEMALE,
    idle:       FEMALE
  };

  /* ── What the guide says, page by page ─────────────────────────────── */
  var SCRIPTS = {
    'index.html': {
      pose: 'welcome',
      text: 'Namaste! I\'m your <b>Virasat Guide</b>. Scroll down and I\'ll walk you through everything this app can do — from exploring cities to stepping back in time in VR.'
    },
    'scan.html': {
      pose: 'photo',
      text: 'This is the <b>Monument Scanner</b>. Upload or take a photo of any Indian monument and I\'ll identify it, then tell you its history, the crafts and food of its region, and take you straight to that city in Explore.'
    },
    'marketplace.html': {
      pose: 'pointing',
      text: 'Welcome to the <b>Heritage Marketplace</b>. Every piece here is GI-tagged and comes straight from the artisan who made it — tap a product to read its origin story, save it to your wishlist with the heart, or filter by region.'
    },
    'events.html': {
      pose: 'excited',
      text: 'These are <b>Cultural Events</b> across India — festivals, craft melas and celebrations. Pick a date or a region to plan your visit around a living tradition, and use the budget planner to work out what the trip will cost.'
    },
    'language.html': {
      pose: 'explaining',
      text: 'This is the <b>Language Studio</b>. Choose an Indian language, learn the greetings and phrases a traveller actually needs, and tap the speaker to hear them spoken naturally. You can also translate your own sentences into any of them.'
    },
    'profile.html': {
      pose: 'welcome',
      text: 'This is <b>your profile</b> — your saved crafts, your free scans remaining, and your explorer level. Everything here is tied to the account you signed in with.'
    },
    'community.html': {
      pose: 'excited',
      text: 'Welcome to the <b>Virasat Community</b>. Share dispatches from your journeys — photos, craft discoveries, stories. And if you hit a road block or closure on the way to a monument, post a <b>Travel Alert</b>: it is verified against your live location, so fellow travellers can trust it.'
    },
    'report.html': {
      pose: 'explaining',
      text: 'This is <b>Report a Problem</b>. If you see damage, litter or a safety hazard at a monument, describe it here, add a photo, verify your location on-site, and your complaint goes to heritage officials — with a certificate for you as a heritage guardian.'
    },
    'artisan.html': {
      pose: 'pointing',
      text: 'This is the <b>Artisan Dashboard</b>. List your handmade products with their origin story and they appear in the marketplace for travellers across India.'
    },
    'login.html': {
      pose: 'welcome',
      text: 'Namaste! Sign in as a traveller to explore, or as an artisan to sell your craft. Your scans, wishlist and posts are saved to your account.'
    }
  };

  /* Home-page feature slides, in the order they appear (data-feat index). */
  var FEATURES = [
    { pose: 'pointing',   text: 'First, <b>Explore City</b>. Pick any heritage city and I\'ll take you through its monuments, crafts, food, festivals and the people who keep its traditions alive.' },
    { pose: 'photo',      text: 'Next, <b>Scan Monument</b>. Point your camera at a monument and our AI identifies it instantly and tells you its story.' },
    { pose: 'excited',    text: 'The <b>Marketplace</b> — handcrafted, GI-tagged products bought directly from the artisans, each with the story of where it came from.' },
    { pose: 'excited',    text: '<b>Cultural Events</b> — festivals and craft melas happening across India, so you can plan a trip around a living celebration.' },
    { pose: 'explaining', text: '<b>Language Translation</b> — learn the greetings and phrases of any Indian region, and hear them spoken the way locals say them.' },
    { pose: 'excited',    text: 'The <b>Community</b> — share your own journey, photos and craft finds with fellow explorers.' },
    { pose: 'explaining', text: '<b>Report a Problem</b> — spotted damage or litter at a monument? File a complaint with a photo and it reaches heritage officials directly.' },
    { pose: 'welcome',    text: 'Your <b>Profile</b> — your saved crafts, your explorer level and everything tied to your account.' },
    { pose: 'pointing',   text: 'And finally the <b>VR Monument Explorer</b> — walk through 360° tours, and flip the Chronos Lens to see how the monument looked a century ago.' }
  ];

  /* ── UI ─────────────────────────────────────────────────────────────── */
  var css = ''
    + '#vgWrap{position:fixed;left:18px;bottom:16px;z-index:9000;display:flex;align-items:flex-end;gap:10px;pointer-events:none;font-family:"Plus Jakarta Sans","Outfit",Inter,system-ui,sans-serif}'
    + '#vgChar{width:150px;height:180px;object-fit:contain;object-position:bottom;pointer-events:auto;cursor:pointer;filter:drop-shadow(0 10px 22px rgba(0,0,0,.45));transition:transform .25s ease;transform-origin:bottom center}'
    + '#vgChar:hover{transform:scale(1.04)}'
    + '#vgChar.speaking{animation:vgBob 1.4s ease-in-out infinite}'
    + '@keyframes vgBob{0%,100%{transform:translateY(0)}50%{transform:translateY(-4px)}}'
    + '#vgBubble{pointer-events:auto;max-width:min(360px,calc(100vw - 170px));background:rgba(12,14,22,.92);color:#fff;border:1px solid rgba(201,168,76,.45);border-radius:16px;padding:12px 14px 10px;box-shadow:0 14px 40px rgba(0,0,0,.45);backdrop-filter:blur(10px);position:relative;margin-bottom:22px;opacity:0;transform:translateY(8px);transition:opacity .3s ease,transform .3s ease}'
    + '#vgWrap.open #vgBubble{opacity:1;transform:translateY(0)}'
    + '#vgBubble:after{content:"";position:absolute;left:-8px;bottom:26px;border:8px solid transparent;border-right-color:rgba(12,14,22,.92);border-left:0}'
    + '#vgLabel{font-size:10px;letter-spacing:2px;text-transform:uppercase;color:#c9a84c;font-weight:800;margin-bottom:6px;display:flex;justify-content:space-between;align-items:center;gap:8px}'
    + '#vgText{font-size:13.5px;line-height:1.55;color:rgba(255,255,255,.92)}'
    + '#vgText b{color:#f5e1a4}'
    + '#vgBtns{display:flex;gap:6px;margin-top:8px}'
    + '.vgBtn{background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14);color:#fff;border-radius:8px;padding:4px 9px;font-size:12px;cursor:pointer;font-family:inherit}'
    + '.vgBtn:hover{background:rgba(201,168,76,.25);border-color:#c9a84c}'
    + '.vgBtn.pulse{animation:vgPulse 1.2s ease-in-out infinite}'
    + '@keyframes vgPulse{0%,100%{box-shadow:0 0 0 0 rgba(201,168,76,.5)}50%{box-shadow:0 0 0 6px rgba(201,168,76,0)}}'
    + '#vgWrap.closed #vgBubble{display:none}'
    + '#vgWrap.closed #vgChar{width:86px;height:104px;opacity:.85}'
    + '@media (max-width:600px){#vgChar{width:104px;height:126px}#vgBubble{max-width:calc(100vw - 130px);font-size:12.5px}}';

  var style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  var wrap = document.createElement('div');
  wrap.id = 'vgWrap';
  wrap.innerHTML =
    '<img id="vgChar" src="' + POSE.welcome + '" alt="Virasat Guide" title="Click me to repeat">'
    + '<div id="vgBubble" role="status" aria-live="polite">'
    +   '<div id="vgLabel"><span>🧭 Virasat Guide</span><button class="vgBtn" id="vgClose" title="Hide" aria-label="Hide guide">✕</button></div>'
    +   '<div id="vgText"></div>'
    +   '<div id="vgBtns">'
    +     '<button class="vgBtn" id="vgReplay" title="Listen again">🔁 Replay</button>'
    +     '<button class="vgBtn" id="vgMute" title="Mute / unmute">🔊 Sound on</button>'
    +   '</div>'
    + '</div>';
  document.body.appendChild(wrap);

  var elChar = document.getElementById('vgChar');

  // Until female_guide.png is in place, fall back to the male artwork so the
  // guide never shows a broken image. Once it is added, nothing else changes.
  var usingFallback = false;
  elChar.addEventListener('error', function () {
    if (usingFallback) return;
    usingFallback = true;
    Object.keys(POSE).forEach(function (k) { POSE[k] = FALLBACK; });
    elChar.src = FALLBACK;
  });
  var elText = document.getElementById('vgText');
  var elMute = document.getElementById('vgMute');
  var elReplay = document.getElementById('vgReplay');

  var muted = false;
  try { muted = localStorage.getItem('virasat_guide_muted') === '1'; } catch (e) {}
  var closedThisSession = false;
  try { closedThisSession = sessionStorage.getItem('virasat_guide_closed') === '1'; } catch (e) {}
  if (closedThisSession || IN_APP) wrap.classList.add('closed');

  function renderMute() { elMute.textContent = muted ? '🔇 Sound off' : '🔊 Sound on'; }
  renderMute();

  /* ── Speech ─────────────────────────────────────────────────────────── */
  var token = 0;
  var neuralAvailable = null;
  var audio = null;
  var lastSpoken = '';
  var pendingGesture = null;         // speech blocked until the user interacts

  function stripHtml(s) {
    var d = document.createElement('div'); d.innerHTML = s; return (d.textContent || '').replace(/\s+/g, ' ').trim();
  }
  function speakingOn() { elChar.classList.add('speaking'); markPending(false); }
  function speakingOff() { elChar.classList.remove('speaking'); }

  /* Browsers refuse audio until the visitor has clicked or tapped once.
     While a line is waiting for that, pulse Replay so it is obvious that a
     tap will make her talk — otherwise she just looks silent. */
  function markPending(on) {
    elReplay.classList.toggle('pulse', !!on);
    elReplay.textContent = on ? '🔊 Tap to hear' : '🔁 Replay';
  }

  // Chrome fills the voice list asynchronously; touching it early means the
  // first utterance gets a real voice instead of the engine default.
  if ('speechSynthesis' in window) {
    try { window.speechSynthesis.getVoices(); } catch (e) {}
  }

  function stop() {
    token++;
    if (audio) { try { audio.pause(); } catch (e) {} audio = null; }
    if ('speechSynthesis' in window) window.speechSynthesis.cancel();
    speakingOff();
  }

  function proxyBase() {
    var h = window.location.hostname || 'localhost';
    return (window.location.protocol.startsWith('http') ? '' : 'http://localhost:3005');
  }

  function speakNeural(text, t) {
    if (neuralAvailable === false) return Promise.resolve(false);
    return fetch(proxyBase() + '/api/speech', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text: text })
    }).then(function (res) {
      if (!res.ok) { neuralAvailable = false; return false; }
      return res.blob().then(function (blob) {
        if (t !== token) return true;
        neuralAvailable = true;
        audio = new Audio(URL.createObjectURL(blob));
        audio.onplay = speakingOn;
        audio.onended = audio.onerror = function () { speakingOff(); };
        return audio.play().then(function () { return true; }, function () {
          // Autoplay blocked: wait for the first interaction, then try again.
          pendingGesture = text; markPending(true); return true;
        });
      });
    }).catch(function () { neuralAvailable = false; return false; });
  }

  function bestVoice() {
    if (!('speechSynthesis' in window)) return null;
    var v = window.speechSynthesis.getVoices() || [];
    var score = function (x) {
      var l = (x.lang || '').toLowerCase(), n = (x.name || '').toLowerCase(), s = 0;
      if (l === 'en-in') s += 100; else if (l.indexOf('en') === 0) s += 40;
      if (/neural|natural|online|google|premium/.test(n)) s += 30;
      if (/espeak|compact/.test(n)) s -= 100;
      return s;
    };
    return v.slice().sort(function (a, b) { return score(b) - score(a); })[0] || null;
  }

  function speakBrowser(text, t) {
    if (!('speechSynthesis' in window)) return;
    var synth = window.speechSynthesis;
    var v = bestVoice();
    // Mobile engines cut off after ~15s; sentence-sized chunks avoid that.
    var chunks = text.match(/[^.!?।]+[.!?।]*\s*/g) || [text];
    var merged = [], cur = '';
    chunks.forEach(function (c) {
      if ((cur + c).length > 180 && cur) { merged.push(cur); cur = c; } else cur += c;
    });
    if (cur.trim()) merged.push(cur);
    var started = false;
    merged.forEach(function (part, i) {
      var u = new SpeechSynthesisUtterance(part.trim());
      if (v) { u.voice = v; u.lang = v.lang; } else { u.lang = 'en-IN'; }
      u.rate = 0.96; u.pitch = 1.04;
      u.onstart = function () { started = true; if (t === token) speakingOn(); };
      u.onerror = function (e) {
        speakingOff();
        if (e && (e.error === 'not-allowed' || e.error === 'audio-busy')) { pendingGesture = text; markPending(true); }
      };
      if (i === merged.length - 1) u.onend = function () { speakingOff(); };
      synth.speak(u);
    });
    // Chrome silently drops utterances queued before voices load or
    // before the first tap: surface a "tap to hear" prompt instead.
    setTimeout(function () {
      if (t === token && !started && !synth.speaking && !synth.pending) {
        pendingGesture = text; markPending(true);
      }
    }, 1200);
    // Android Chrome pauses synthesis when it thinks the queue is stuck.
    if (/android/i.test(navigator.userAgent)) {
      var kick = setInterval(function () {
        if (t !== token || !synth.speaking) { clearInterval(kick); return; }
        synth.pause(); synth.resume();
      }, 8000);
    }
  }

  function speak(text, t) {
    if (neuralAvailable === false) { speakBrowser(text, t); return; }
    speakNeural(text, t).then(function (done) {
      if (!done && t === token) speakBrowser(text, t);
    });
  }

  // Ask the proxy once whether the neural voice exists at all, so phones
  // don't burn their tap on a request that is going to fail anyway.
  try {
    fetch(proxyBase() + '/api/health').then(function (r) { return r.json(); }).then(function (j) {
      if (j && j.voice === false) neuralAvailable = false;
    }).catch(function () {});
  } catch (e) {}

  function say(html, poseKey, opts) {
    opts = opts || {};
    elText.innerHTML = html;
    elChar.src = POSE[poseKey] || POSE.explaining;
    wrap.classList.add('open');
    lastSpoken = stripHtml(html);
    if (muted || wrap.classList.contains('closed')) return;
    stop();
    speak(lastSpoken, token);
  }

  // Browsers may refuse audio before the visitor has interacted with the
  // page. If that happened, the first click/keypress replays the line.
  function onFirstGesture() {
    if (pendingGesture && !muted) {
      var text = pendingGesture; pendingGesture = null; markPending(false);
      stop(); speak(text, token);
    }
  }
  ['pointerdown', 'keydown', 'touchstart'].forEach(function (ev) {
    document.addEventListener(ev, onFirstGesture, { passive: true });
  });
  if (pendingGesture === null && 'speechSynthesis' in window) {
    window.speechSynthesis.addEventListener('voiceschanged', function () { /* voices ready */ });
  }

  /* ── Controls ────────────────────────────────────────────────────────── */
  elMute.addEventListener('click', function () {
    muted = !muted;
    try { localStorage.setItem('virasat_guide_muted', muted ? '1' : '0'); } catch (e) {}
    renderMute();
    if (muted) stop(); else if (lastSpoken) { stop(); speak(lastSpoken, token); }
  });
  elReplay.addEventListener('click', function () {
    if (!lastSpoken) return;
    stop(); speak(lastSpoken, token);
  });
  document.getElementById('vgClose').addEventListener('click', function () {
    wrap.classList.add('closed'); stop();
    try { sessionStorage.setItem('virasat_guide_closed', '1'); } catch (e) {}
  });
  elChar.addEventListener('click', function () {
    var wasClosed = wrap.classList.contains('closed');
    if (wasClosed) {
      wrap.classList.remove('closed');
      try { sessionStorage.removeItem('virasat_guide_closed'); } catch (e) {}
    }
    // In the app she hasn't introduced the page yet: the first tap does it.
    if (!lastSpoken && script) { say(script.text, script.pose); return; }
    if (lastSpoken) elReplay.click();
  });

  // Turning the page: stop talking so narration never overlaps the next page.
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href]');
    if (a && /\.html/i.test(a.getAttribute('href') || '')) stop();
  }, true);
  window.addEventListener('pagehide', stop);

  /* ── Page intro ─────────────────────────────────────────────────────── */
  var script = SCRIPTS[page];
  if (script && !IN_APP) setTimeout(function () { say(script.text, script.pose); }, 700);

  /* ── Home page: follow the feature slides ───────────────────────────── */
  if (page === 'index.html' && !IN_APP) {
    var slides = document.querySelectorAll('.feature-slide');
    if (slides.length) {
      var lastFeat = -1, featTimer = 0;
      var onChange = function () {
        var active = document.querySelector('.feature-slide.active');
        var idx = active ? parseInt(active.getAttribute('data-feat'), 10) : -1;
        if (idx === lastFeat) return;
        lastFeat = idx;
        clearTimeout(featTimer);
        // Settle for a beat so fast scrolling doesn't stutter through every slide.
        featTimer = setTimeout(function () {
          if (idx >= 0 && FEATURES[idx]) say(FEATURES[idx].text, FEATURES[idx].pose);
          else if (idx === -1 && script) say(script.text, script.pose);
        }, 650);
      };
      var mo = new MutationObserver(onChange);
      slides.forEach(function (s) { mo.observe(s, { attributes: true, attributeFilter: ['class'] }); });
    }
  }

  window.VirasatGuide = { say: say, stop: stop };
})();
