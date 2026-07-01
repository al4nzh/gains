package exercisedb

const staticGIFMediaBase = gifMediaBase

// catalogGifIDs maps normalized Gains catalog exercise names to ExerciseDB exercise ids.
// Static URLs are used first so GIFs work without downloading the full ExerciseDB index.
var catalogGifIDs = map[string]string{
	"arnold press":                "Xy4jlWA",
	"barbell curl":                "25GPyDY",
	"barbell row":                 "eZyBC3j",
	"bench press":                 "EIeI8Vf",
	"bulgarian split squat":       "9E25EOx",
	"cable crunch":                "WW95auq",
	"cable fly":                   "27NNGFr",
	"cable row":                   "fUBheHs",
	"calf raise":                  "1LVFcEn",
	"chin up":                     "G70mEAJ",
	"close grip bench press":      "da4cXST",
	"curls":                       "3s4NnTh",
	"deadlift":                    "ila4NZS",
	"dip":                         "9WTm7dq",
	"dumbbell bench press":        "SpYC0Kp",
	"dumbbell row":                "BJ0Hz5L",
	"dumbbell shoulder press":     "A6wtbuL",
	"face pull":                   "SpsOSXk",
	"farmer carry":                "qPEzJjA",
	"front raise":                 "3eGE2JC",
	"front squat":                 "zG0zs85",
	"hammer curl":                 "2NpxjC1",
	"hanging leg raise":           "I3tsCnC",
	"hip thrust":                  "qKBpF7I",
	"incline bench press":         "3TZduzM",
	"incline db press":            "ns0SIbU",
	"kettlebell swing":            "UHJlbu3",
	"lat pulldown":                "7F1DVzn",
	"lateral raise":               "DsgkuIt",
	"leg curl":                    "17lJ1kr",
	"leg extension":               "my33uHU",
	"leg press":                   "2Qh2J1e",
	"ohp":                         "kTbSH9h",
	"overhead triceps extension":  "5fKX7wi",
	"pendlay row":                 "r0z6xzQ",
	"plank":                       "VBAWRPG",
	"preacher curl":               "7D5bgLT",
	"pull up":                     "lBDjFxJ",
	"push up":                     "B1EVP9F",
	"rear delt fly":               "Ion0XWz",
	"romanian deadlift":           "wQ2c4XD",
	"skull crusher":               "h8LFzo9",
	"squat":                       "qXTaZnJ",
	"sumo deadlift":               "KgI0tqW",
	"t bar row":                   "aaXr7ld",
	"triceps pushdown":            "3ZflifB",
	"walking lunge":               "IZVHb27",

	// Expanded catalog (000024)
	"decline bench press":         "GrO65fd", // barbell decline bench press
	"machine chest press":         "DOoWcnA", // lever chest press (machine)
	"dumbbell fly":                "ESOd5Pl", // dumbbell incline fly
	"straight-arm pulldown":       "x69MAlq", // cable straight arm pulldown
	"machine pulldown":            "ecpY0rH", // reverse grip machine lat pulldown
	"shrug":                       "JymLInS", // dumbbell incline shrug
	"goblet squat":                "yn8yg1r", // dumbbell goblet squat
	"hack squat":                  "5VCj6iH", // barbell hack squat
	"smith squat":                 "jFtipLl", // smith squat
	"good morning":                "XlZ4lAC", // barbell good morning
	"glute bridge":                "qKBpF7I", // barbell glute bridge
	"step up":                     "aXtJhlg", // dumbbell step-up
	"seated leg curl":             "Zg3XY7P", // lever seated leg curl (machine)
	"seated calf raise":           "bOOdeyc", // lever seated calf raise (machine)
	"standing calf raise":         "ykUOVze", // lever standing calf raise (machine)
	"machine shoulder press":      "67n3r98", // lever shoulder press (machine)
	"cable lateral raise":         "goJ6ezq", // cable lateral raise
	"upright row":                 "UDlhcO8", // barbell upright row
	"ez bar curl":                 "6TG6x2w", // ez barbell curl
	"cable curl":                  "BCGQ6J5", // cable close grip curl
	"incline db curl":             "ae9UoXQ", // dumbbell incline curl
	"rope triceps pushdown":       "dU605di", // cable pushdown (with rope attachment)
	"cable overhead triceps extension": "2IxROQ1", // cable overhead triceps extension (rope attachment)
	"russian twist":               "XVDdcoj", // russian twist
	"side plank":                  "5VXmnV5", // bodyweight incline side plank
}

func staticCatalogGIFURL(normCatalogName string) (string, bool) {
	id, ok := catalogGifIDs[normCatalogName]
	if !ok || id == "" {
		return "", false
	}
	return staticGIFMediaBase + id + ".gif", true
}
