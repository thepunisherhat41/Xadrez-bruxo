let audioContext = null;
let masterGain = null;
let muted = false;

function context() {
  if (typeof window === 'undefined') return null;
  if (!audioContext) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return null;
    audioContext = new AudioContext();
    masterGain = audioContext.createGain();
    masterGain.gain.value = 0.28;
    masterGain.connect(audioContext.destination);
  }
  return audioContext;
}

function unlock() {
  const ctx = context();
  if (ctx?.state === 'suspended') ctx.resume().catch(() => {});
}

function tone({ frequency = 220, endFrequency = frequency, duration = 0.18, volume = 0.12, type = 'sine', delay = 0 }) {
  if (muted) return;
  const ctx = context();
  if (!ctx || !masterGain) return;

  const start = ctx.currentTime + delay;
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, start);
  oscillator.frequency.exponentialRampToValueAtTime(Math.max(20, endFrequency), start + duration);
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(Math.max(0.001, volume), start + 0.018);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain);
  gain.connect(masterGain);
  oscillator.start(start);
  oscillator.stop(start + duration + 0.02);
}

function noise({ duration = 0.16, volume = 0.12, delay = 0, cutoff = 1200 }) {
  if (muted) return;
  const ctx = context();
  if (!ctx || !masterGain) return;

  const start = ctx.currentTime + delay;
  const frames = Math.max(1, Math.floor(ctx.sampleRate * duration));
  const buffer = ctx.createBuffer(1, frames, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < frames; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / frames);

  const source = ctx.createBufferSource();
  const filter = ctx.createBiquadFilter();
  const gain = ctx.createGain();
  filter.type = 'lowpass';
  filter.frequency.value = cutoff;
  gain.gain.setValueAtTime(volume, start);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  source.buffer = buffer;
  source.connect(filter);
  filter.connect(gain);
  gain.connect(masterGain);
  source.start(start);
}

function playCue(kind) {
  unlock();
  if (muted) return;

  if (kind === 'capture') {
    noise({ duration: 0.22, volume: 0.19, cutoff: 900 });
    tone({ frequency: 105, endFrequency: 48, duration: 0.34, volume: 0.18, type: 'sawtooth' });
    tone({ frequency: 420, endFrequency: 170, duration: 0.16, volume: 0.07, type: 'square', delay: 0.025 });
    return;
  }

  if (kind === 'check') {
    tone({ frequency: 196, endFrequency: 147, duration: 0.42, volume: 0.15, type: 'sawtooth' });
    tone({ frequency: 392, endFrequency: 294, duration: 0.42, volume: 0.08, type: 'triangle' });
    noise({ duration: 0.28, volume: 0.06, cutoff: 650 });
    return;
  }

  if (kind === 'checkmate') {
    noise({ duration: 0.42, volume: 0.2, cutoff: 720 });
    [98, 147, 196].forEach((frequency, index) => {
      tone({ frequency, endFrequency: frequency * 0.72, duration: 1.05, volume: 0.12 - index * 0.018, type: 'sawtooth', delay: index * 0.055 });
    });
    tone({ frequency: 784, endFrequency: 110, duration: 1.15, volume: 0.06, type: 'triangle', delay: 0.12 });
    return;
  }

  if (kind === 'duel') {
    [164, 220, 294, 392].forEach((frequency, index) => {
      tone({ frequency, endFrequency: frequency * 1.08, duration: 0.28, volume: 0.075, type: 'triangle', delay: index * 0.09 });
    });
    return;
  }

  if (kind === 'warning') {
    tone({ frequency: 150, endFrequency: 90, duration: 0.55, volume: 0.12, type: 'square' });
    return;
  }

  if (kind === 'draw') {
    tone({ frequency: 220, endFrequency: 220, duration: 0.52, volume: 0.07, type: 'sine' });
    tone({ frequency: 261.6, endFrequency: 246.9, duration: 0.52, volume: 0.06, type: 'sine' });
    return;
  }

  if (kind === 'ui') {
    tone({ frequency: 420, endFrequency: 510, duration: 0.055, volume: 0.035, type: 'sine' });
  }
}

function announcementKind(node) {
  if (!(node instanceof HTMLElement) || !node.classList.contains('battle-announcement')) return null;
  return ['capture', 'checkmate', 'check', 'duel', 'warning', 'draw'].find((kind) => node.classList.contains(kind)) || null;
}

if (typeof window !== 'undefined') {
  window.addEventListener('pointerdown', unlock, { passive: true });
  window.addEventListener('keydown', (event) => {
    if (event.key.toLowerCase() === 'm') muted = !muted;
  });

  document.addEventListener('click', (event) => {
    if (event.target instanceof Element && event.target.closest('button')) playCue('ui');
  });

  const observer = new MutationObserver((records) => {
    records.forEach((record) => {
      record.addedNodes.forEach((node) => {
        const kind = announcementKind(node);
        if (kind) playCue(kind);
      });
    });
  });

  observer.observe(document.documentElement, { childList: true, subtree: true });
}
