class_name ApplyFailReason

enum Values {
	OK,
	GENERIC_FAIL,
	ALREADY_ACTIVE,
	SKIPPED,
}


static func is_success(reason: int) -> bool:
	return reason == Values.OK


static func uses_generic_fail_message(reason: int) -> bool:
	return reason == Values.GENERIC_FAIL
