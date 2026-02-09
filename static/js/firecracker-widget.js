(() => {
  const STORAGE_KEY = "firecracker_widget_state_v1";
  const POP_MIN = 95;
  const POP_MAX = 190;

  const random = (min, max) => min + Math.random() * (max - min);
  const randInt = (min, max) => Math.floor(random(min, max + 1));

  function createAudioPop() {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return () => {};
    const ctx = new Ctx();
    return () => {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();
      filter.type = "bandpass";
      filter.frequency.value = random(500, 1400);
      osc.type = "triangle";
      osc.frequency.setValueAtTime(random(120, 240), now);
      osc.frequency.exponentialRampToValueAtTime(random(40, 80), now + 0.08);
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.exponentialRampToValueAtTime(0.4, now + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.09);
      osc.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.1);
    };
  }

  function launchSmoke(layer, x, y) {
    const count = randInt(3, 6);
    for (let i = 0; i < count; i += 1) {
      const puff = document.createElement("span");
      puff.className = "smoke-puff";
      puff.style.left = `${x + random(-4, 4)}px`;
      puff.style.top = `${y + random(-3, 3)}px`;
      puff.style.setProperty("--size", `${random(11, 26)}px`);
      puff.style.setProperty("--dx", `${random(-26, 30)}px`);
      puff.style.setProperty("--dy", `${random(-90, -38)}px`);
      puff.style.setProperty("--scale", `${random(1.2, 2.7)}`);
      puff.style.setProperty("--duration", `${random(1.45, 2.8)}s`);
      layer.appendChild(puff);
      setTimeout(() => puff.remove(), 3000);
    }
  }

  function launchPaper(layer, x, y) {
    const colors = ["#b80f0f", "#d11e1e", "#f0c36d", "#bf1a1a", "#a91212"];
    const count = randInt(10, 16);
    for (let i = 0; i < count; i += 1) {
      const bit = document.createElement("span");
      bit.className = "paper-bit";
      bit.style.left = `${x}px`;
      bit.style.top = `${y}px`;
      bit.style.setProperty("--w", `${random(3, 6)}px`);
      bit.style.setProperty("--h", `${random(5, 10)}px`);
      bit.style.setProperty("--color", colors[randInt(0, colors.length - 1)]);
      bit.style.setProperty("--rot", `${random(0, 360)}deg`);
      bit.style.setProperty("--rot-end", `${random(220, 980)}deg`);
      bit.style.setProperty("--drift-x", `${random(-44, 44)}px`);
      bit.style.setProperty("--fall-y", `${random(52, 160)}px`);
      bit.style.setProperty("--duration", `${random(0.9, 1.65)}s`);
      layer.appendChild(bit);
      setTimeout(() => bit.remove(), 1800);
    }
  }

  function launchFlash(layer, x, y) {
    const flash = document.createElement("span");
    flash.className = "fire-flash";
    flash.style.left = `${x}px`;
    flash.style.top = `${y}px`;
    layer.appendChild(flash);
    setTimeout(() => flash.remove(), 300);
  }

  function setFinished(widget, fuse, crackers) {
    widget.classList.remove("is-lit");
    widget.classList.add("is-finished");
    fuse.disabled = true;
    fuse.setAttribute("aria-disabled", "true");
    fuse.title = "已点燃完毕";
    crackers.forEach((cracker) => {
      cracker.classList.remove("is-popping");
      cracker.classList.add("is-spent");
    });
  }

  function init() {
    const widget = document.getElementById("firecracker-widget");
    if (!widget) return;

    const fuse = document.getElementById("firecracker-fuse");
    const chain = document.getElementById("firecracker-chain");
    const smokeLayer = document.getElementById("fire-smoke-layer");
    const paperLayer = document.getElementById("fire-paper-layer");
    if (!fuse || !chain || !smokeLayer || !paperLayer) return;

    const crackers = Array.from(chain.querySelectorAll(".fire-cracker"));
    if (!crackers.length) return;

    if (localStorage.getItem(STORAGE_KEY) === "spent") {
      setFinished(widget, fuse, crackers);
      return;
    }

    let lit = false;
    const playPop = createAudioPop();

    const popOne = (cracker) => {
      const widgetRect = widget.getBoundingClientRect();
      const rect = cracker.getBoundingClientRect();
      const x = rect.left - widgetRect.left + rect.width * 0.5;
      const y = rect.top - widgetRect.top + rect.height * 0.5;

      cracker.classList.add("is-popping");
      launchFlash(smokeLayer, x, y);
      launchSmoke(smokeLayer, x, y);
      launchPaper(paperLayer, x, y);
      playPop();

      widget.classList.remove("is-shaking");
      void widget.offsetWidth;
      widget.classList.add("is-shaking");

      setTimeout(() => {
        cracker.classList.remove("is-popping");
        cracker.classList.add("is-spent");
      }, 180);
    };

    const ignite = () => {
      if (lit) return;
      lit = true;
      widget.classList.add("is-lit");
      fuse.disabled = true;

      let delay = 780;
      crackers.forEach((cracker) => {
        delay += randInt(POP_MIN, POP_MAX);
        setTimeout(() => popOne(cracker), delay);
      });

      setTimeout(() => {
        setFinished(widget, fuse, crackers);
        localStorage.setItem(STORAGE_KEY, "spent");
      }, delay + 450);
    };

    fuse.addEventListener("click", ignite, { passive: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
