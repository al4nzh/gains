package ai

func unitDisplayInstruction(unitSystem string) string {
	switch unitSystem {
	case "imperial":
		return "\n\nUnits: The athlete uses imperial. In all user-facing text use lb for weights (not kg) and ft/in for height. JSON context values are kg/cm — convert when writing."
	default:
		return "\n\nUnits: The athlete uses metric. Use kg and cm in all user-facing text."
	}
}

func normalizeUnitSystem(raw string) string {
	switch raw {
	case "imperial", "metric":
		return raw
	default:
		return "metric"
	}
}
