import { invoke } from "@tauri-apps/api/core";

// ===== DOM refs =====
const track = document.getElementById("sliderTrack");
const thumb = document.getElementById("sliderThumb");
const fill = document.getElementById("sliderFill");
const freqDisplay = document.getElementById("freqDisplay");
const statusDot = document.getElementById("statusDot");
const statusText = document.getElementById("statusText");
const btnStart = document.getElementById("btnStart");
const btnStop = document.getElementById("btnStop");
const app = document.getElementById("app");

// ===== State =====
const MIN_MS = 100;   // 0.1s
const MAX_MS = 1000;  // 1.0s
let intervalMs = 500; // default
let isRunning = false;
let flashState = false;
let timerId = null;
let isDragging = false;

// ===== iOS-style Slider (touch + mouse) =====
function valueToPercent(v) {
  return ((v - MIN_MS) / (MAX_MS - MIN_MS)) * 100;
}

function percentToValue(p) {
  const raw = MIN_MS + (p / 100) * (MAX_MS - MIN_MS);
  // snap to nearest 0.05s
  return Math.round(raw / 50) * 50;
}

function updateSlider(valueMs) {
  const pct = valueToPercent(valueMs);
  fill.style.width = `${pct}%`;
  thumb.style.left = `${pct}%`;
  const secs = (valueMs / 1000).toFixed(1);
  freqDisplay.textContent = `${secs}s`;
  intervalMs = valueMs;
}

function trackToValue(clientX) {
  const rect = track.getBoundingClientRect();
  let pct = ((clientX - rect.left) / rect.width) * 100;
  pct = Math.max(0, Math.min(100, pct));
  return percentToValue(pct);
}

function onPointerStart(e) {
  if (isRunning) return;
  isDragging = true;
  const cx = e.clientX ?? e.touches?.[0]?.clientX;
  if (cx != null) {
    const v = trackToValue(cx);
    updateSlider(v);
  }
}

function onPointerMove(e) {
  if (!isDragging || isRunning) return;
  e.preventDefault();
  const cx = e.clientX ?? e.touches?.[0]?.clientX;
  if (cx != null) {
    const v = trackToValue(cx);
    updateSlider(v);
  }
}

function onPointerEnd() {
  isDragging = false;
}

track.addEventListener("pointerdown", onPointerStart);
track.addEventListener("touchstart", (e) => onPointerStart(e), { passive: true });
document.addEventListener("pointermove", onPointerMove);
document.addEventListener("touchmove", onPointerMove, { passive: false });
document.addEventListener("pointerup", onPointerEnd);
document.addEventListener("touchend", onPointerEnd);

// ===== Flash control =====
async function flash(on) {
  try {
    return on ? await invoke("flash_on") : await invoke("flash_off");
  } catch {
    return false;
  }
}

function setStatus(active) {
  statusDot.classList.toggle("active", active);
  statusText.textContent = active ? "爆闪中" : "就绪";
  app.classList.toggle("strobing", active);
}

async function flashLoop() {
  if (!isRunning) return;
  flashState = !flashState;
  await flash(flashState);
  timerId = setTimeout(flashLoop, intervalMs);
}

async function start() {
  if (isRunning) return;
  isRunning = true;
  flashState = false;
  setStatus(true);
  btnStart.disabled = true;
  btnStop.disabled = false;
  thumb.classList.add("active");
  // turn on immediately for first flash
  flashState = true;
  await flash(true);
  timerId = setTimeout(flashLoop, intervalMs);
}

async function stop() {
  if (!isRunning) return;
  isRunning = false;
  if (timerId) {
    clearTimeout(timerId);
    timerId = null;
  }
  flashState = false;
  await flash(false);
  setStatus(false);
  btnStart.disabled = false;
  btnStop.disabled = true;
  thumb.classList.remove("active");
}

btnStart.addEventListener("click", start);
btnStop.addEventListener("click", stop);

// ===== Init =====
updateSlider(intervalMs);
btnStop.disabled = true;

// Prevent screen from dimming — keeps display on while app is active
// Tauri v2 on iOS: we handle this natively in Swift
