extends Node

signal updated

const TARGET_BINS_PER_SECOND := 110.0
const FRAMES_PER_PASS := 65536

var peaks := PackedFloat32Array()
var completed := 0
var bins_per_second := 0.0

var _bytes := PackedByteArray()
var _bytes_per_sample := 0
var _channels := 0
var _frames := 0
var _frames_per_bin := 0

func _ready() -> void:
	set_process(false)

func begin(stream: AudioStreamWAV) -> void:
	_bytes.clear()
	peaks.clear()
	completed = 0
	bins_per_second = 0.0
	set_process(false)
	if stream != null:
		_bytes = stream.data
		_bytes_per_sample = 1 if stream.format == AudioStreamWAV.FORMAT_8_BITS else 2
		_channels = 2 if stream.stereo else 1
		@warning_ignore("integer_division")
		_frames = _bytes.size() / (_bytes_per_sample * _channels)
		_frames_per_bin = maxi(1, roundi(stream.mix_rate / TARGET_BINS_PER_SECOND))
		bins_per_second = float(stream.mix_rate) / _frames_per_bin
		peaks.resize(ceili(float(_frames) / _frames_per_bin))
		set_process(true)
	updated.emit()

func _process(_delta: float) -> void:
	@warning_ignore("integer_division")
	var limit := mini(peaks.size(), completed + maxi(1, FRAMES_PER_PASS / _frames_per_bin))
	var bytes_per_frame := _bytes_per_sample * _channels
	for bin in range(completed, limit):
		var end := mini(_frames, (bin + 1) * _frames_per_bin) * bytes_per_frame
		var peak := 0
		for at in range(bin * _frames_per_bin * bytes_per_frame, end, _bytes_per_sample):
			var sample := _bytes.decode_s8(at) if _bytes_per_sample == 1 else _bytes.decode_s16(at)
			peak = maxi(peak, absi(sample))
		peaks[bin] = float(peak) / (128.0 if _bytes_per_sample == 1 else 32768.0)
	completed = limit
	if completed == peaks.size():
		_bytes.clear()
		set_process(false)
	updated.emit()
