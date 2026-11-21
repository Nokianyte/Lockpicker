extends Node

signal web_finished(result: Array)

const Chart = preload("res://scripts/song_chart.gd")
const MAX_AUDIO_BYTES := 128 * 1024 * 1024
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
		pick(callback, limit) {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.wav,audio/wav,audio/wave';
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
				if (file.size > limit) return callback('Choose a WAV file under 128 MiB.');
				try {
					callback('', file.name, await file.arrayBuffer());
				} catch (error) {
					callback(error.message || 'Could not read the song.');
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
		bytes = FileAccess.get_file_as_bytes(_audio_path(chart.audio_id))
	var stream := decode_song(bytes)
	if stream == null:
		return {"error": "The saved song could not be opened."}
	return {"chart": chart, "stream": stream}

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
	var audio_path := _audio_path(chart.audio_id)
	if not FileAccess.file_exists(audio_path):
		if new_audio.is_empty() or not _write_atomic(audio_path, new_audio):
			return "Could not save the imported song."
	if not _write_atomic(directory.path_join(chart.id + ".json"), json.to_utf8_buffer()):
		return "Could not save the chart."
	return ""

func pick_web_song() -> Dictionary:
	if _web == null:
		return {"error": "The browser file picker is unavailable."}
	_web.pick(_callback, MAX_AUDIO_BYTES)
	var response: Array = await web_finished
	if response[0] != "":
		return {"error": response[0]}
	if response.size() == 1:
		return {}
	return {"name": response[1], "bytes": response[2]}

static func read_song_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Could not read the selected song."}
	if file.get_length() > MAX_AUDIO_BYTES:
		return {"error": "Choose a WAV file under 128 MiB."}
	return {"name": path.get_file(), "bytes": file.get_buffer(file.get_length())}

static func decode_song(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44 or bytes.size() > MAX_AUDIO_BYTES:
		return null
	var stream := AudioStreamWAV.load_from_buffer(bytes)
	if stream == null or stream.get_length() <= 0.0 or stream.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
		return null
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _audio_path(id: String) -> String:
	return directory.path_join(id + ".wav")

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
