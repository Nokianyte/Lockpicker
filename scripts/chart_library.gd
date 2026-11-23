extends Node

signal web_finished(result: Array)

const Chart = preload("res://scripts/song_chart.gd")
const Package = preload("res://scripts/chart_package.gd")
const MAX_AUDIO_BYTES := Package.MAX_AUDIO_BYTES
const AUDIO_SIZE_ERROR := "Choose an MP3 or WAV file under 128 MiB."
const PACKAGE_SIZE_ERROR := "This chart package is too large."
const MP3_DECODE_RATE := 44100
const MP3_FRAMES_PER_PASS := 32768
const PCM_STEREO_FRAME_BYTES := 4
const WEB_STORAGE := """
window.lockpickerChartStorage = (function () {
	const database = new Promise((resolve, reject) => {
		const request = indexedDB.open('lockpicker-charts', 1);
		request.onupgradeneeded = () => {
			request.result.createObjectStore('charts');
			request.result.createObjectStore('audio');
		};
		request.onsuccess = () => resolve(request.result);
		request.onerror = () => reject(request.error);
		request.onblocked = () => reject(new Error('Chart storage is unavailable'));
	});
	database.catch(() => {});
	const run = (callback, action) => database.then(db => action(db))
		.then(result => callback('', ...result), error => callback(error.message || 'Chart storage failed'));
	const transact = (db, stores, mode, action) => new Promise((resolve, reject) => {
		const transaction = db.transaction(stores, mode);
		let result = [];
		transaction.oncomplete = () => resolve(result);
		transaction.onabort = () => reject(transaction.error || new Error('Chart audio is unavailable'));
		action(transaction, value => { result = value; });
	});
	return {
		list(callback) {
			run(callback, db => transact(db, ['charts'], 'readonly', (tx, result) => {
				const request = tx.objectStore('charts').getAll();
				request.onsuccess = () => result([request.result.join(String.fromCharCode(10))]);
			}));
		},
		load(callback, id) {
			run(callback, db => transact(db, ['charts', 'audio'], 'readonly', (tx, result) => {
				const chart = tx.objectStore('charts').get(id);
				chart.onsuccess = () => {
					if (!chart.result) return tx.abort();
					const audio = tx.objectStore('audio').get(JSON.parse(chart.result).audio_id);
					audio.onsuccess = () => {
						if (audio.result) result([chart.result, audio.result]);
						else tx.abort();
					};
				};
			}));
		},
		save(callback, id, record, audioId, encodedAudio) {
			run(callback, db => transact(db, ['charts', 'audio'], 'readwrite', tx => {
				const charts = tx.objectStore('charts');
				const audio = tx.objectStore('audio');
				if (encodedAudio) {
					const decoded = atob(encodedAudio);
					const bytes = new Uint8Array(decoded.length);
					for (let index = 0; index < decoded.length; index++) bytes[index] = decoded.charCodeAt(index);
					audio.put(bytes.buffer, audioId);
					charts.put(record, id);
				} else {
					const request = audio.getKey(audioId);
					request.onsuccess = () => {
						if (request.result) charts.put(record, id);
						else tx.abort();
					};
				}
			}));
		},
		pick(callback, accept, limit, sizeError) {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = accept;
			input.hidden = true;
			document.body.appendChild(input);
			input.addEventListener('cancel', () => {
				input.remove();
				callback('');
			}, {once: true});
			input.addEventListener('change', async () => {
				const file = input.files[0];
				input.remove();
				if (!file) return callback('');
				if (file.size > limit) return callback(sizeError);
				try {
					callback('', file.name, await file.arrayBuffer());
				} catch (error) {
					callback(error.message || 'Could not read the selected file.');
				}
			}, {once: true});
			input.click();
		}
	};
})()
"""

var directory := "user://charts"
var _web: JavaScriptObject
var _callback: JavaScriptObject

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_STORAGE, true)
		_web = JavaScriptBridge.get_interface("lockpickerChartStorage")
		_callback = JavaScriptBridge.create_callback(_receive_web)

func _receive_web(args: Array) -> void:
	var response := args.duplicate()
	if response.size() == 3 and response[2] is JavaScriptObject:
		response[2] = JavaScriptBridge.js_buffer_to_packed_byte_array(response[2])
	web_finished.emit.call_deferred(response)

func list_charts() -> Dictionary:
	var records := PackedStringArray()
	if _web != null:
		_web.list(_callback)
		var response: Array = await web_finished
		if response[0] != "":
			return {"error": response[0]}
		records = response[1].split("\n", false)
	elif DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			if file.get_extension() == "json":
				records.append(FileAccess.get_file_as_string(directory.path_join(file)))
	var charts: Array[Dictionary] = []
	for record in records:
		var chart = Chart.from_record(JSON.parse_string(record))
		if chart != null:
			charts.append({"id": chart.id, "title": chart.title, "audio_name": chart.audio_name})
	charts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.title.naturalnocasecmp_to(b.title) < 0)
	return {"charts": charts}

func read_chart(id: String) -> Dictionary:
	var data := await _read_chart_data(id)
	if data.has("error"):
		return data
	var stream := await decode_song(data.audio, data.chart.audio_name)
	if stream == null:
		return {"error": "The saved song could not be opened."}
	return {"chart": data.chart, "stream": stream}

func _read_chart_data(id: String) -> Dictionary:
	if not Chart.valid_id(id):
		return {"error": "The chart ID is invalid."}
	var record: Variant
	var bytes := PackedByteArray()
	if _web != null:
		_web.load(_callback, id)
		var response: Array = await web_finished
		if response[0] != "":
			return {"error": response[0]}
		record = JSON.parse_string(response[1])
		bytes = response[2]
	else:
		var path := directory.path_join(id + ".json")
		if FileAccess.file_exists(path):
			record = JSON.parse_string(FileAccess.get_file_as_string(path))
	var chart = Chart.from_record(record)
	if chart == null or chart.id != id:
		return {"error": "Could not read this chart."}
	if _web == null:
		bytes = FileAccess.get_file_as_bytes(_audio_path(chart.audio_id, chart.audio_name))
	if bytes.is_empty():
		return {"error": "The saved song could not be opened."}
	return {"chart": chart, "audio": bytes}

func import_package(bytes: PackedByteArray) -> String:
	var data := Package.unpack(bytes)
	if data.is_empty():
		return "Could not read this .lockchart package."
	var chart: Chart = data.chart
	if await decode_song(data.audio, chart.audio_name) == null:
		return "Could not open the song in this chart package."
	chart.id = Chart.new_id()
	chart.audio_id = Chart.new_id()
	return await save_chart(chart, data.audio)

func export_package(id: String) -> Dictionary:
	var data := await _read_chart_data(id)
	if data.has("error"):
		return data
	var bytes := Package.pack(data.chart, data.audio)
	if bytes.is_empty():
		return {"error": "Could not package this chart and its song."}
	return {"name": data.chart.title.strip_edges().validate_filename() + "." + Package.EXTENSION, "bytes": bytes}

func write_package_file(path: String, bytes: PackedByteArray) -> String:
	if path.get_extension().to_lower() != Package.EXTENSION:
		path += "." + Package.EXTENSION
	return "" if _write_atomic(path, bytes) else "Could not write the chart package."

func save_chart(chart, new_audio: PackedByteArray) -> String:
	var record: Dictionary = chart.record()
	if Chart.from_record(record) == null:
		return "Enter a chart name and import a song before saving."
	var json := JSON.stringify(record)
	if _web != null:
		var encoded := Marshalls.raw_to_base64(new_audio) if not new_audio.is_empty() else ""
		_web.save(_callback, chart.id, json, chart.audio_id, encoded)
		var response: Array = await web_finished
		return response[0]
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "Could not create the local chart folder."
	var audio_path := _audio_path(chart.audio_id, chart.audio_name)
	if not FileAccess.file_exists(audio_path):
		if new_audio.is_empty() or not _write_atomic(audio_path, new_audio):
			return "Could not save the imported song."
	if not _write_atomic(directory.path_join(chart.id + ".json"), json.to_utf8_buffer()):
		return "Could not save the chart."
	return ""

func pick_web_song() -> Dictionary:
	return await _pick_web_file(".mp3,.wav,audio/mpeg,audio/wav,audio/wave", MAX_AUDIO_BYTES, AUDIO_SIZE_ERROR)

func pick_web_package() -> Dictionary:
	return await _pick_web_file("." + Package.EXTENSION, Package.MAX_FILE_BYTES, PACKAGE_SIZE_ERROR)

func _pick_web_file(accept: String, limit: int, size_error: String) -> Dictionary:
	if _web == null:
		return {"error": "The browser file picker is unavailable."}
	_web.pick(_callback, accept, limit, size_error)
	var response: Array = await web_finished
	if response[0] != "":
		return {"error": response[0]}
	if response.size() == 1:
		return {}
	return {"name": response[1], "bytes": response[2]}

static func read_song_file(path: String) -> Dictionary:
	return _read_selected_file(path, MAX_AUDIO_BYTES, AUDIO_SIZE_ERROR)

static func read_package_file(path: String) -> Dictionary:
	return _read_selected_file(path, Package.MAX_FILE_BYTES, PACKAGE_SIZE_ERROR)

static func _read_selected_file(path: String, limit: int, size_error: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Could not read the selected file."}
	if file.get_length() > limit:
		return {"error": size_error}
	return {"name": path.get_file(), "bytes": file.get_buffer(file.get_length())}

func decode_song(bytes: PackedByteArray, filename: String) -> AudioStreamWAV:
	if bytes.is_empty() or bytes.size() > MAX_AUDIO_BYTES:
		return null
	if filename.get_extension().to_lower() == "mp3":
		return await _decode_mp3(bytes)
	if bytes.size() < 44:
		return null
	var stream := AudioStreamWAV.load_from_buffer(bytes)
	if stream == null or stream.get_length() <= 0.0 or stream.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
		return null
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _decode_mp3(bytes: PackedByteArray) -> AudioStreamWAV:
	var mp3 := AudioStreamMP3.load_from_buffer(bytes)
	if mp3 == null:
		return null
	var expected_frames := roundi(mp3.get_length() * MP3_DECODE_RATE)
	var expected_size := expected_frames * PCM_STEREO_FRAME_BYTES
	if expected_size <= 0 or expected_size > MAX_AUDIO_BYTES:
		return null
	var pcm := PackedByteArray()
	if pcm.resize(expected_size) != OK:
		return null

	# Mix a private playback so preview, playtest, and waveform share the same decoded samples.
	var decoder := mp3.instantiate_playback()
	if decoder == null:
		return null
	decoder.start()
	var rate_scale := float(AudioServer.get_mix_rate()) / MP3_DECODE_RATE
	var frames_written := 0
	while frames_written < expected_frames:
		var count := mini(MP3_FRAMES_PER_PASS, expected_frames - frames_written)
		var samples := decoder.mix_audio(rate_scale, count)
		for frame in samples:
			var offset := frames_written * PCM_STEREO_FRAME_BYTES
			pcm.encode_s16(offset, clampi(roundi(frame.x * 32768.0), -32768, 32767))
			pcm.encode_s16(offset + 2, clampi(roundi(frame.y * 32768.0), -32768, 32767))
			frames_written += 1
		if samples.size() < count:
			break
		if frames_written < expected_frames:
			await get_tree().process_frame
	decoder.stop()
	if frames_written == 0:
		return null
	pcm.resize(frames_written * PCM_STEREO_FRAME_BYTES)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MP3_DECODE_RATE
	stream.stereo = true
	stream.data = pcm
	return stream

func _audio_path(id: String, filename: String) -> String:
	var extension := ".mp3" if filename.get_extension().to_lower() == "mp3" else ".wav"
	return directory.path_join(id + extension)

func _write_atomic(path: String, contents: PackedByteArray) -> bool:
	var temporary := path + "." + Chart.new_id() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var written := file.store_buffer(contents)
	file.flush()
	written = written and file.get_error() == OK
	file.close()
	if written and DirAccess.rename_absolute(temporary, path) == OK:
		return true
	DirAccess.remove_absolute(temporary)
	return false
