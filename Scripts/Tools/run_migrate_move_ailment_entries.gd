extends SceneTree

func _init() -> void:
	var result := MigrateMoveAilmentEntriesCore.migrate_all()
	print("[run_migrate_move_ailment_entries] Resultado: ", result)
	quit()
