extends AudioStreamPlayer

signal song_ended

const WEB_AUDIO := """
window.lockpickerSongAudio ??= (function () {
	let context, gain, buffer, songId, source;
	let volume = 1;
	let started = null, request = null, offset = 0, limit = 0;
	function prepare() {
		if (context) return;
		context = new AudioContext();
		gain = context.createGain();
		gain.gain.value = volume;
		gain.connect(context.destination);
	}
	function unlock() {
		prepare();
		return context.resume().catch(() => {});
	}
	function position() {
		if (started === null || context.state !== 'running') return offset;
		let clock;
		if (context.getOutputTimestamp) {
			const output = context.getOutputTimestamp();
			// A stale timestamp from before playback can otherwise advance the chart too early.
			if (!output.performanceTime || output.contextTime < started) return offset;
			const elapsed = (performance.now() - output.performanceTime) / 1000;
			clock = Math.min(context.currentTime, output.contextTime + elapsed);
		} else {
			clock = context.currentTime - (context.baseLatency || 0) - (context.outputLatency || 0);
		}
		return Math.min(limit, offset + Math.max(0, clock - started));
	}
	return {
		unlock,
		setVolume(level) {
			volume = level;
			if (gain) gain.gain.value = level;
		},
		hasSong(id) {
			return songId === id;
		},
		loadPcm(id, encoded, rate, channels, bytesPerSample) {
			prepare();
			const decoded = atob(encoded);
			const frameSize = channels * bytesPerSample;
			buffer = context.createBuffer(channels, Math.floor(decoded.length / frameSize), rate);
			for (let channel = 0; channel < channels; channel++) {
				const output = buffer.getChannelData(channel);
				for (let frame = 0; frame < output.length; frame++) {
					const at = (frame * channels + channel) * bytesPerSample;
					const low = decoded.charCodeAt(at);
					if (bytesPerSample === 1) {
						output[frame] = (low << 24 >> 24) / 128;
					} else {
						const sample = low | (decoded.charCodeAt(at + 1) << 8);
						output[frame] = (sample << 16 >> 16) / 32768;
					}
				}
			}
			songId = id;
		},
		play(position, end) {
			const ready = unlock();
			const song = buffer;
			const current = {};
			request = current;
			started = null;
			offset = position;
			limit = end;
			const start = () => {
				if (request !== current || context.state !== 'running') return;
				source = context.createBufferSource();
				source.buffer = song;
				source.connect(gain);
				started = context.currentTime + 0.04;
				source.start(started, position, end - position);
			};
			// Give the browser a turn to refresh currentTime after a blocking PCM upload.
			ready.then(() => setTimeout(start, 0));
		},
		stop() {
			request = null;
			offset = position();
			started = null;
			if (!source) return;
			source.stop();
			source.disconnect();
			source = null;
		},
		position
	};
})()
"""

var running := false
var song: AudioStreamWAV
var playback_start := 0.0
var playback_end := 0.0
var _position := 0.0
var _native_start := 0.0
var _native_play_position := 0.0
var _output_latency := -1.0
var _tail_start_usec := 0
var _tail_position := 0.0
var _web: JavaScriptObject

func _ready() -> void:
	finished.connect(_audio_finished)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_AUDIO, true)
		_web = JavaScriptBridge.get_interface("lockpickerSongAudio")

func load_song(audio: AudioStreamWAV) -> void:
	pause_song()
	song = audio
	playback_start = 0.0
	playback_end = duration()
	stream = null
	_position = 0.0

func duration() -> float:
	return song.get_length() if song != null else 0.0

func set_playback_range(start: float, end: float) -> void:
	if start == playback_start and end == playback_end:
		return
	pause_song()
	playback_start = start
	playback_end = end
	_position = clampf(_position, start, end)
	stream = null

func start_at(seconds: float) -> void:
	seek_to(seconds)
	resume_song()

func unlock_audio() -> void:
	if _web != null:
		_web.unlock()

func set_web_volume(level: float) -> void:
	if _web != null:
		_web.setVolume(level)

func resume_song() -> void:
	if running or song == null or _position >= playback_end:
		return
	_tail_start_usec = 0
	if _web == null:
		if stream == null:
			_prepare_native_stream()
		_output_latency = -1.0
		_native_play_position = maxf(0.0, _position - _native_start)
		play(_native_play_position)
	else:
		var id := str(song.get_instance_id())
		if not _web.hasSong(id):
			var bytes_per_sample := 1 if song.format == AudioStreamWAV.FORMAT_8_BITS else 2
			_web.loadPcm(id, Marshalls.raw_to_base64(song.data), song.mix_rate, 2 if song.stereo else 1, bytes_per_sample)
		_web.play(_position, playback_end)
	running = true

func _prepare_native_stream() -> void:
	_native_start = 0.0
	if playback_start == 0.0 and playback_end == duration():
		stream = song
		return
	# Let the mixer stop at a sample boundary while keeping the chart clock in source time.
	var bytes_per_sample := 1 if song.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var frame_bytes := bytes_per_sample * (2 if song.stereo else 1)
	var start_frame := floori(playback_start * song.mix_rate)
	var end_frame := maxi(start_frame + 1, roundi(playback_end * song.mix_rate))
	var clip := AudioStreamWAV.new()
	clip.format = song.format
	clip.mix_rate = song.mix_rate
	clip.stereo = song.stereo
	clip.data = song.data.slice(start_frame * frame_bytes, end_frame * frame_bytes)
	_native_start = float(start_frame) / song.mix_rate
	stream = clip

func pause_song() -> void:
	if running:
		song_time()
		if _web != null:
			_web.stop()
	running = false
	_tail_start_usec = 0
	stop()

func seek_to(seconds: float) -> void:
	var was_running := running
	pause_song()
	_position = clampf(seconds, playback_start, playback_end)
	if was_running:
		resume_song()

func song_time() -> float:
	if not running:
		return _position
	if _web != null:
		_position = clampf(_web.position(), _position, playback_end)
	elif _tail_start_usec > 0:
		_position = minf(playback_end, _tail_position + (Time.get_ticks_usec() - _tail_start_usec) / 1000000.0)
	elif playing and has_stream_playback():
		var mixed_position := get_playback_position()
		if _output_latency < 0.0:
			if mixed_position <= _native_play_position:
				return _position
			_output_latency = AudioServer.get_output_latency()
		var position := _native_start + mixed_position + AudioServer.get_time_since_last_mix() - _output_latency
		_position = clampf(position, _position, playback_end)
	return _position

func _audio_finished() -> void:
	if running:
		if _output_latency < 0.0:
			_output_latency = AudioServer.get_output_latency()
		_tail_position = maxf(_position, playback_end - _output_latency)
		_tail_start_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if running and (_web != null or _tail_start_usec > 0) and song_time() >= playback_end:
		pause_song()
		song_ended.emit()
