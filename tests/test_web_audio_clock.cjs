const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

let now = 1000;
let device;
let finishResume;
const starts = [];
const tasks = [];

class TestAudioContext {
  constructor() {
    device = this;
    this.state = 'suspended';
    this.currentTime = 0;
    this.output = {contextTime: 0, performanceTime: 0};
  }

  resume() {
    if (this.state === 'running') return Promise.resolve();
    return new Promise(resolve => { finishResume = resolve; });
  }

  createGain() { return {gain: {}, connect() {}}; }
  createBuffer() { return {getChannelData: () => new Float32Array(1)}; }
  createBufferSource() { return {connect() {}, disconnect() {}, start: when => starts.push(when), stop() {}}; }
  getOutputTimestamp() { return this.output; }
}

async function checkColdPlayback() {
  const window = {};
  const transport = fs.readFileSync(path.join(__dirname, '../scripts/song_transport.gd'), 'utf8');
  const [, script] = transport.match(/const WEB_AUDIO := """([\s\S]*?)"""/);
  vm.runInNewContext(script, {window, AudioContext: TestAudioContext, atob, performance: {now: () => now}, setTimeout: task => tasks.push(task)});
  const audio = window.lockpickerSongAudio;
  audio.loadPcm('song', 'AAA=', 44100, 1, 2);

  const offset = 73.2;
  audio.play(offset, 80);
  assert.equal(audio.position(), offset);
  device.state = 'running';
  finishResume();
  await new Promise(setImmediate);
  assert.equal(starts.length, 0, 'scheduling must wait for the browser to refresh currentTime');
  assert.equal(tasks.length, 1);
  device.currentTime = 0.8;
  tasks.shift()();
  assert.ok(starts[0] > device.currentTime, 'the first source must be scheduled using the refreshed clock');

  device.currentTime = starts[0] + 0.20;
  device.output = {contextTime: starts[0] - 0.05, performanceTime: 1000};
  now = 1250;
  assert.equal(audio.position(), offset, 'a stale timestamp cannot start the chart ahead of audio output');
  device.output = {contextTime: starts[0] + 0.02, performanceTime: 1240};
  assert.ok(Math.abs(audio.position() - (offset + 0.03)) < 1e-9, 'the chart must follow the audio output once it starts');

  audio.stop();
  audio.play(offset, 80);
  assert.equal(audio.position(), offset);
  await new Promise(setImmediate);
  audio.stop();
  tasks.shift()();
  assert.equal(starts.length, 1, 'a pending restart must be canceled when the chart stops');
}

checkColdPlayback().then(() => console.log('Web audio clock checks passed.'), error => {
  console.error(error);
  process.exitCode = 1;
});
