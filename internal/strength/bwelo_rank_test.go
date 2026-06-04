package strength

import "testing"

func TestRankLabelForGender_femaleLowerThresholds(t *testing.T) {
	female := GenderFemale
	if got := RankLabelForGender(700, &female); got != "iron" {
		t.Fatalf("female 700: got %q want iron", got)
	}
	if got := RankLabelForGender(750, &female); got != "bronze" {
		t.Fatalf("female 750: got %q want bronze", got)
	}
	if got := RankLabelForGender(900, &female); got != "silver" {
		t.Fatalf("female 900: got %q want silver", got)
	}
	if got := RankLabelForGender(1000, &female); got != "silver" {
		t.Fatalf("female 1000: got %q want silver", got)
	}
	if got := RankLabelForGender(1150, &female); got != "gold" {
		t.Fatalf("female 1150: got %q want gold", got)
	}
	if got := RankLabelForGender(1300, &female); got != "platinum" {
		t.Fatalf("female 1300: got %q want platinum", got)
	}
}

func TestRankLabelForGender_defaultMaleThresholds(t *testing.T) {
	if got := RankLabelForGender(750, nil); got != "iron" {
		t.Fatalf("default 750: got %q want iron", got)
	}
	male := "male"
	if got := RankLabelForGender(1000, &male); got != "silver" {
		t.Fatalf("male 1000: got %q want silver", got)
	}
}
