extends RefCounted

const Chart = preload("res://scripts/song_chart.gd")
const EXTENSION := "lockchart"
const MAGIC := "LKC1"
const HEADER_BYTES := 12
const MAX_METADATA_BYTES := 16 * 1024 * 1024
const MAX_AUDIO_BYTES := 128 * 1024 * 1024
const MAX_FILE_BYTES := HEADER_BYTES + MAX_METADATA_BYTES + MAX_AUDIO_BYTES

# A versioned header stores the JSON and audio lengths before the two payloads.
static func pack(chart: Chart, audio: PackedByteArray) -> PackedByteArray:
	var metadata := JSON.stringify(chart.record()).to_utf8_buffer()
	if metadata.size() > MAX_METADATA_BYTES or audio.is_empty() or audio.size() > MAX_AUDIO_BYTES:
		return PackedByteArray()
	var bytes := MAGIC.to_ascii_buffer()
	bytes.resize(HEADER_BYTES)
	bytes.encode_u32(4, metadata.size())
	bytes.encode_u32(8, audio.size())
	bytes.append_array(metadata)
	bytes.append_array(audio)
	return bytes

static func unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() <= HEADER_BYTES or bytes.size() > MAX_FILE_BYTES or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {}
	var metadata_size := bytes.decode_u32(4)
	var audio_size := bytes.decode_u32(8)
	var audio_start := HEADER_BYTES + metadata_size
	if metadata_size == 0 or metadata_size > MAX_METADATA_BYTES or audio_size == 0 or audio_size > MAX_AUDIO_BYTES or audio_start + audio_size != bytes.size():
		return {}
	var chart: Chart = Chart.from_record(JSON.parse_string(bytes.slice(HEADER_BYTES, audio_start).get_string_from_utf8()))
	if chart == null or chart.audio_name.get_extension().to_lower() not in ["mp3", "wav"]:
		return {}
	return {"chart": chart, "audio": bytes.slice(audio_start)}
