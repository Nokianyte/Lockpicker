extends AudioStreamPlayer

signal song_ended

const WEB_AUDIO := """
window.lockpickerSongAudio ??= (function () {
	let context, buffer, songId, source;
	let started = 0, offset = 0;
	function unlock() {
		context ??= new AudioContext();
		context.resume().catch(() => {});
	}
	return {
		unlock,
		hasSong(id) {
			return songId === id;
		},
		loadPcm(id, encoded, rate, channels, bytesPerSample) {
			context ??= new AudioContext();
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
		play(position) {
			unlock();
			source = context.createBufferSource();
			source.buffer = buffer;
			source.connect(context.destination);
			started = context.currentTime;
			offset = position;
			source.start(started, offset);
		},
		stop() {
			if (!source) return;
			source.stop();
			source.disconnect();
			source = null;
		},
		position() {
			const audible = context.getOutputTimestamp?.().contextTime;
			const clock = audible > 0 ? audible : context.currentTime - (context.baseLatency || 0) - (context.outputLatency || 0);
			return Math.min(buffer.duration, offset + Math.max(0, clock - started));
		}
	};
})()
"""

var running := false
var _position := 0.0
var _output_latency := 0.0
var _tail_start_usec := 0
var _tail_position := 0.0
var _web: JavaScriptObject

func _ready() -> void:
	finished.connect(_audio_finished)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_AUDIO, true)
		_web = JavaScriptBridge.get_interface("lockpickerSongAudio")

func load_song(song: AudioStream) -> void:
	pause_song()
	stream = song
	_position = 0.0

func duration() -> float:
	return stream.get_length() if stream != null else 0.0

func start_at(seconds: float) -> void:
	seek_to(seconds)
	resume_song()

func unlock_audio() -> void:
	if _web != null:
		_web.unlock()

func resume_song() -> void:
	if running or stream == null or _position >= duration():
		return
	_tail_start_usec = 0
	if _web == null:
		_output_latency = AudioServer.get_output_latency()
		play(_position)
	else:
		var wav := stream as AudioStreamWAV
		var id := str(wav.get_instance_id())
		if not _web.hasSong(id):
			var bytes_per_sample := 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
			_web.loadPcm(id, Marshalls.raw_to_base64(wav.data), wav.mix_rate, 2 if wav.stereo else 1, bytes_per_sample)
		_web.play(_position)
	running = true

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
	_position = clampf(seconds, 0.0, duration())
	if was_running:
		resume_song()

func song_time() -> float:
	if not running:
		return _position
	if _web != null:
		_position = clampf(_web.position(), _position, duration())
	elif _tail_start_usec > 0:
		_position = minf(duration(), _tail_position + (Time.get_ticks_usec() - _tail_start_usec) / 1000000.0)
	elif playing and has_stream_playback():
		var position := get_playback_position() + AudioServer.get_time_since_last_mix() - _output_latency
		_position = clampf(position, _position, duration())
	return _position

func _audio_finished() -> void:
	if running:
		_tail_position = maxf(_position, duration() - _output_latency)
		_tail_start_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if running and (_web != null or _tail_start_usec > 0) and song_time() >= duration():
		pause_song()
		song_ended.emit()
