// Force the Zoom web app to always think it is unfocused / hidden.
//
// Zoom (like most web apps) suppresses desktop notifications when it believes
// the tab is focused and visible. On Wayland, Chromium never reports a blur /
// visibility change when you switch Hyprland workspaces (crbug 365143359), so
// Zoom stays silent and you miss messages. By pinning the focus/visibility
// APIs to "hidden", Zoom always concludes you're not looking and notifies.
//
// Runs in the MAIN world at document_start, so these overrides are in place
// before Zoom's own scripts read them.
(() => {
  "use strict";

  const force = (obj, prop, val) => {
    try {
      Object.defineProperty(obj, prop, { configurable: true, get: () => val });
    } catch (_) {
      /* some props are non-configurable in certain engines; ignore */
    }
  };

  // --- Page Visibility API: always "hidden" ---
  force(Document.prototype, "hidden", true);
  force(Document.prototype, "visibilityState", "hidden");
  force(Document.prototype, "webkitHidden", true);
  force(Document.prototype, "webkitVisibilityState", "hidden");

  // --- Focus: always unfocused ---
  Document.prototype.hasFocus = () => false;

  // Stop window/document-level "focus" events from telling the app it became
  // active again. Element-level focus (inputs, etc.) is untouched because the
  // listener target there is the element, not window/document.
  const origAdd = EventTarget.prototype.addEventListener;
  EventTarget.prototype.addEventListener = function (type, listener, opts) {
    if ((this === window || this === document) && type === "focus") return;
    return origAdd.call(this, type, listener, opts);
  };
  try {
    Object.defineProperty(window, "onfocus", {
      configurable: true,
      get: () => null,
      set: () => {},
    });
  } catch (_) {}

  // Nudge any listeners that registered before us to re-read the (now forced)
  // hidden/blurred state.
  const announce = () => {
    document.dispatchEvent(new Event("visibilitychange"));
    window.dispatchEvent(new Event("blur"));
  };
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", announce, { once: true });
  } else {
    announce();
  }
})();
