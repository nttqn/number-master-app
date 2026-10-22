// Synthesises the two looping background-music tracks into assets/audio as
// 16-bit mono WAV — pure Node, no samples, same approach as the sibling
// games' tool/gen_music.js. Run from the project root:
//   node tool/gen_music.js
//
// Style: bright "tropical summer" pop in G major, to match the sky/bridge
// look — a marimba (menu) or steel-pan (game) lead on the major
// pentatonic, off-beat ukulele-like chord chops, a bouncy bass, and a light
// shaker/kick/clap groove. Progressions are the I-V-vi-IV family.
//
// Every note is mixed *circularly* into a buffer exactly one loop long, so
// tails that ring past the end wrap around to the start — the loop point is
// seamless instead of ending in a gap of silence.
const fs = require('fs');
const path = require('path');

const RATE = 22050;
const OUT = path.join(__dirname, '..', 'assets', 'audio');
fs.mkdirSync(OUT, { recursive: true });

let seed = 24680;
const noise = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x3fffffff - 1;
};

function write(name, samples, peak) {
  let max = 0;
  for (const s of samples) max = Math.max(max, Math.abs(s));
  const gain = max > 0 ? peak / max : 1;
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => data.writeInt16LE(Math.round(s * gain * 32767), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVEfmt ', 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(OUT, name), Buffer.concat([head, data]));
  console.log(name, (samples.length / RATE).toFixed(2) + 's', Math.round((44 + data.length) / 1024) + 'KB');
}

const midiFreq = (n) => 440 * Math.pow(2, (n - 69) / 12);
const TAU = 2 * Math.PI;

// Mixes `synth(t)` for `durSec` into `target` at `startSec`, wrapping past
// the end back to the start (see header).
function addNote(target, startSec, durSec, synth) {
  const from = Math.round(startSec * RATE);
  const count = Math.round(durSec * RATE);
  const n = target.length;
  for (let i = 0; i < count; i++) {
    target[(from + i) % n] += synth(i / RATE);
  }
}

// ---- Instruments ---------------------------------------------------------

// Marimba: fundamental plus the bar's characteristic ~4x overtone, which
// dies away much faster than the fundamental; soft mallet click on attack.
function marimba(f, gain = 1) {
  return (t) => {
    const atk = Math.min(1, t * 900);
    return gain * atk * (Math.sin(TAU * f * t) * Math.exp(-t * 7) + 0.3 * Math.sin(TAU * f * 3.93 * t) * Math.exp(-t * 28));
  };
}

// Steel pan: bright, slightly inharmonic partials with a gentle wobble.
function steelPan(f, gain = 1) {
  return (t) => {
    const atk = Math.min(1, t * 700);
    const wob = 1 + 0.003 * Math.sin(TAU * 5.5 * t);
    const env = Math.exp(-t * 4.2);
    return gain * atk * env * (
      Math.sin(TAU * f * wob * t) +
      0.5 * Math.sin(TAU * f * 2.0 * t) * Math.exp(-t * 3) +
      0.28 * Math.sin(TAU * f * 3.01 * t) * Math.exp(-t * 6) +
      0.12 * Math.sin(TAU * f * 4.05 * t) * Math.exp(-t * 10)
    );
  };
}

// Short ukulele-ish chord chop: plucked triangle-ish tone, quick decay.
function chop(f, gain = 0.3) {
  return (t) => {
    const atk = Math.min(1, t * 1200);
    const ph = (f * t) % 1;
    const tri = 4 * Math.abs(ph - 0.5) - 1;
    return gain * atk * Math.exp(-t * 16) * (0.7 * tri + 0.3 * Math.sin(TAU * 2 * f * t));
  };
}

// Round, bouncy bass.
function bass(f, gain = 0.9) {
  return (t) => {
    const atk = Math.min(1, t * 400);
    return gain * atk * Math.exp(-t * 4.5) * (Math.sin(TAU * f * t) + 0.25 * Math.sin(TAU * 2 * f * t));
  };
}

// Soft kick: a quick downward pitch sweep.
function kick(gain = 0.8) {
  return (t) => {
    const f = 50 + 70 * Math.exp(-t * 30);
    return gain * Math.exp(-t * 14) * Math.sin(TAU * f * t);
  };
}

// Noise burst through a simple one-pole high-pass, for shaker/clap.
function noiseHit(target, startSec, durSec, decay, gain, hp = 0.85) {
  const from = Math.round(startSec * RATE);
  const count = Math.round(durSec * RATE);
  let prevIn = 0, prevOut = 0;
  for (let i = 0; i < count; i++) {
    const x = noise();
    const y = hp * (prevOut + x - prevIn);
    prevIn = x;
    prevOut = y;
    target[(from + i) % target.length] += gain * y * Math.exp(-(i / RATE) * decay);
  }
}

// ---- Harmony -------------------------------------------------------------

const CHORDS = {
  G: [55, 59, 62],
  D: [57, 62, 66],
  Em: [59, 64, 67],
  C: [55, 60, 64],
  Bm: [59, 62, 66],
};
const ROOT = { G: 43, D: 38, Em: 40, C: 36, Bm: 47 };
const FIFTH = { G: 50, D: 45, Em: 47, C: 43, Bm: 42 };

// Chord chops on every off-beat ("and" of each beat).
function chopsBar(x, barStart, spb, chord, gain) {
  for (let beat = 0; beat < 4; beat++) {
    for (const n of CHORDS[chord]) addNote(x, barStart + (beat + 0.5) * spb, spb * 0.45, chop(midiFreq(n), gain));
  }
}

function leadBar(x, barStart, spb, notes, instrument, gain) {
  for (const [beat, midi, dur] of notes) {
    addNote(x, barStart + beat * spb, Math.max(dur * spb * 1.6, 0.5), instrument(midiFreq(midi), gain));
  }
}

// ---- Tracks --------------------------------------------------------------

function composeMenu() {
  const bpm = 104;
  const spb = 60 / bpm;
  const prog = ['G', 'D', 'Em', 'C', 'G', 'D', 'C', 'D'];
  const melody = [
    [[0, 74, 0.5], [0.5, 76, 0.5], [1, 79, 1], [2.5, 76, 0.5], [3, 74, 1]],
    [[0, 74, 0.5], [0.5, 71, 0.5], [1, 69, 1], [2, 74, 1.5], [3.5, 69, 0.5]],
    [[0, 71, 0.5], [0.5, 74, 0.5], [1, 76, 1], [2.5, 79, 0.5], [3, 76, 1]],
    [[0, 74, 1.5], [1.5, 71, 0.5], [2, 69, 2]],
    [[0, 74, 0.5], [0.5, 76, 0.5], [1, 79, 1], [2, 81, 0.5], [2.5, 79, 0.5], [3, 76, 1]],
    [[0, 78, 0.5], [0.5, 76, 0.5], [1, 74, 1], [2, 69, 1], [3, 74, 1]],
    [[0, 76, 1], [1, 74, 0.5], [1.5, 71, 0.5], [2, 69, 1], [3, 71, 1]],
    [[0, 69, 1], [1, 71, 0.5], [1.5, 74, 0.5], [2, 69, 1], [3, 66, 1]],
  ];
  const x = new Float64Array(Math.round(prog.length * 4 * spb * RATE));
  prog.forEach((chord, bar) => {
    const s = bar * 4 * spb;
    chopsBar(x, s, spb, chord, 0.22);
    addNote(x, s, spb * 1.8, bass(midiFreq(ROOT[chord])));
    addNote(x, s + 2 * spb, spb * 1.8, bass(midiFreq(FIFTH[chord]), 0.75));
    leadBar(x, s, spb, melody[bar], marimba, 0.85);
    // Echo of the melody an octave up, a beat and a half later, very soft —
    // adds sparkle without a second composed part.
    leadBar(x, s + 1.5 * spb, spb, melody[bar].map(([b, m, d]) => [b, m + 12, d]), marimba, 0.12);
    addNote(x, s, 0.3, kick(0.5));
    addNote(x, s + 2 * spb, 0.3, kick(0.4));
    for (let e = 0; e < 8; e++) noiseHit(x, s + e * 0.5 * spb, 0.06, 60, e % 2 ? 0.05 : 0.09);
  });
  write('bgm_menu.wav', x, 0.75);
}

function composeGame() {
  const bpm = 128;
  const spb = 60 / bpm;
  const prog = ['G', 'D', 'Em', 'C', 'G', 'D', 'C', 'D', 'C', 'D', 'Bm', 'Em', 'C', 'D', 'Em', 'D'];
  const melody = [
    [[0, 79, 0.5], [0.5, 76, 0.5], [1, 74, 0.5], [1.5, 76, 0.5], [2, 79, 1], [3, 81, 0.5], [3.5, 79, 0.5]],
    [[0, 78, 0.5], [0.5, 74, 0.5], [1, 69, 0.5], [1.5, 74, 0.5], [2, 78, 1], [3, 76, 1]],
    [[0, 76, 0.5], [0.5, 79, 0.5], [1, 83, 0.5], [1.5, 79, 0.5], [2, 76, 1], [3, 74, 0.5], [3.5, 76, 0.5]],
    [[0, 72, 0.5], [0.5, 76, 0.5], [1, 79, 1], [2, 76, 0.5], [2.5, 74, 0.5], [3, 72, 1]],
    [[0, 79, 0.5], [0.5, 76, 0.5], [1, 74, 0.5], [1.5, 76, 0.5], [2, 79, 1], [3, 81, 0.5], [3.5, 79, 0.5]],
    [[0, 78, 0.5], [0.5, 81, 0.5], [1, 78, 0.5], [1.5, 74, 0.5], [2, 69, 1], [3, 74, 1]],
    [[0, 76, 0.5], [0.5, 79, 0.5], [1, 84, 1], [2, 83, 0.5], [2.5, 81, 0.5], [3, 79, 1]],
    [[0, 78, 1], [1, 76, 0.5], [1.5, 74, 0.5], [2, 69, 2]],
    [[0, 84, 1], [1, 83, 0.5], [1.5, 81, 0.5], [2, 79, 1], [3, 76, 1]],
    [[0, 78, 1], [1, 81, 0.5], [1.5, 78, 0.5], [2, 74, 2]],
    [[0, 83, 1], [1, 81, 0.5], [1.5, 78, 0.5], [2, 74, 1], [3, 78, 1]],
    [[0, 79, 1.5], [1.5, 76, 0.5], [2, 71, 2]],
    [[0, 76, 0.5], [0.5, 79, 0.5], [1, 84, 0.5], [1.5, 79, 0.5], [2, 76, 0.5], [2.5, 79, 0.5], [3, 84, 1]],
    [[0, 81, 0.5], [0.5, 78, 0.5], [1, 74, 0.5], [1.5, 78, 0.5], [2, 81, 1], [3, 86, 1]],
    [[0, 83, 1], [1, 79, 0.5], [1.5, 76, 0.5], [2, 79, 1], [3, 83, 1]],
    [[0, 81, 1], [1, 78, 1], [2, 74, 1], [3, 78, 1]],
  ];
  const x = new Float64Array(Math.round(prog.length * 4 * spb * RATE));
  prog.forEach((chord, bar) => {
    const s = bar * 4 * spb;
    chopsBar(x, s, spb, chord, 0.2);
    // Bouncy bass: root, octave pickup, fifth, root pickup.
    addNote(x, s, spb * 1.2, bass(midiFreq(ROOT[chord])));
    addNote(x, s + 1.5 * spb, spb * 0.6, bass(midiFreq(ROOT[chord] + 12), 0.55));
    addNote(x, s + 2 * spb, spb * 1.2, bass(midiFreq(FIFTH[chord]), 0.8));
    addNote(x, s + 3.5 * spb, spb * 0.6, bass(midiFreq(ROOT[chord]), 0.6));
    leadBar(x, s, spb, melody[bar], steelPan, 0.8);
    for (let beat = 0; beat < 4; beat++) addNote(x, s + beat * spb, 0.3, kick(beat % 2 ? 0.45 : 0.7));
    noiseHit(x, s + spb, 0.14, 26, 0.32, 0.7); // clap on 2
    noiseHit(x, s + 3 * spb, 0.14, 26, 0.32, 0.7); // clap on 4
    for (let e = 0; e < 16; e++) noiseHit(x, s + e * 0.25 * spb, 0.05, 70, e % 4 === 2 ? 0.1 : 0.05);
  });
  write('bgm_game.wav', x, 0.78);
}

composeMenu();
composeGame();
