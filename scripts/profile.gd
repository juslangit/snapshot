class_name Profile
extends RefCounted

## Everything the game remembers between sessions: the settings, the best score
## on each job, and the photo album.
##
## Settings and scores live in one ConfigFile; the album is a folder of PNGs
## with an index.json beside them, so the photographs are real files a player
## could find and keep. All of it sits under `root`, which the checks point at
## a throwaway folder so running them never touches a real player's album.

static var root := "user://"

const DEFAULTS := {
	"look_sensitivity": 1.0,
	"volume": 0.8,
	"show_legend": true,
	"grid": true,
	"fullscreen": false,
}

static var _config: ConfigFile

static func _file() -> String:
	return root.path_join("profile.cfg")

static func _album_dir() -> String:
	return root.path_join("album")

static func _load() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(_file())
	return _config

## Forget what is in memory, so the next read comes from disk. Used when
## `root` changes.
static func reload() -> void:
	_config = null

static func _save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_load().save(_file())

# -- settings -----------------------------------------------------------------

static func setting(key: String) -> Variant:
	return _load().get_value("settings", key, DEFAULTS.get(key))

static func set_setting(key: String, value: Variant) -> void:
	_load().set_value("settings", key, value)
	_save()
	apply_settings()

## Push the settings that live outside the game's own scripts - sound and the
## window - into the engine.
static func apply_settings() -> void:
	var volume: float = setting("volume")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var want_full: bool = setting("fullscreen")
		var is_full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if want_full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_MAXIMIZED)

# -- best scores --------------------------------------------------------------

## The best average a job has been handed in with, or -1 if it never has.
static func best_score(brief_index: int) -> int:
	return _load().get_value("best", str(brief_index), -1)

static func record_score(brief_index: int, score: int) -> bool:
	if score <= best_score(brief_index):
		return false
	_load().set_value("best", str(brief_index), score)
	_save()
	return true

# -- the album ----------------------------------------------------------------

## One kept photograph: the picture, and enough about it to caption it.
static func keep_photo(photo: Image, client: String, shot_title: String, score: int, settings: String) -> String:
	var dir := _album_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var name_text := "%s_%d.png" % [stamp, Time.get_ticks_msec() % 1000]
	photo.save_png(ProjectSettings.globalize_path(dir.path_join(name_text)))
	var entries := album()
	entries.push_front({
		"file": name_text,
		"client": client,
		"shot": shot_title,
		"score": score,
		"settings": settings,
		"date": Time.get_date_string_from_system(),
	})
	_write_album(entries)
	return name_text

## Newest first.
static func album() -> Array:
	var path := _album_dir().path_join("index.json")
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

static func album_image(entry: Dictionary) -> Image:
	var path := ProjectSettings.globalize_path(_album_dir().path_join(entry.get("file", "")))
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)

static func forget_photo(entry: Dictionary) -> void:
	var entries := album()
	for i in entries.size():
		if entries[i].get("file") == entry.get("file"):
			entries.remove_at(i)
			break
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_album_dir().path_join(entry.get("file", ""))))
	_write_album(entries)

static func _write_album(entries: Array) -> void:
	var file := FileAccess.open(_album_dir().path_join("index.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(entries, "  "))

## Wipe everything under root. Only ever called on the checks' own folder.
static func erase_all() -> void:
	var album_path := ProjectSettings.globalize_path(_album_dir())
	if DirAccess.dir_exists_absolute(album_path):
		for f in DirAccess.get_files_at(album_path):
			DirAccess.remove_absolute(album_path.path_join(f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_file()))
	reload()
