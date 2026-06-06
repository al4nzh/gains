package ai

import "testing"

func TestParseTitleMessageStructured(t *testing.T) {
	raw := `{"title":"Squat performance dropped today","message":"You did 85 kg × 6 for 510 kg volume. Compared to your last similar squat session, volume was down 22.7% and e1RM dropped from 127.7 kg → 98.7 kg.\n\nLikely reason: moderate energy/readiness, not necessarily strength loss.\n\nNext move: keep next squat session lighter or rebuild volume gradually."}`
	title, message := parseTitleMessage(raw)
	if title != "Squat performance dropped today" {
		t.Fatalf("title = %q", title)
	}
	if message == "" {
		t.Fatal("expected message")
	}
	if len(message) < 50 {
		t.Fatalf("message too short: %q", message)
	}
}
