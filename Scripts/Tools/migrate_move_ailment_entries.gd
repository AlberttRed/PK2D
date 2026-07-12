@tool
extends EditorScript

## Editor > Tools > Execute Script
func _run() -> void:
	MigrateMoveAilmentEntriesCore.migrate_all()
