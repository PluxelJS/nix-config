package main

import "testing"

func TestNormalizeKDEGlobals(t *testing.T) {
	input := []byte(`[General]
ColorScheme=CatppuccinMacchiatoLavender
ColorSchemeHash=generated


[Colors:Selection]
ForegroundLink=old
ForegroundActive=accent
ForegroundLink=current
`)
	want := `[General]
ColorScheme=CatppuccinMacchiatoLavender

[Colors:Selection]
ForegroundActive=accent
ForegroundLink=current
`
	if got := string(normalizeKDEGlobals(input)); got != want {
		t.Fatalf("normalized kdeglobals mismatch\nwant:\n%s\ngot:\n%s", want, got)
	}
}

func TestNormalizeKDEAppConfigsDropsRuntimeState(t *testing.T) {
	dolphin := []byte(`[General]
DoubleClickViewAction=go_back
Version=202
ViewPropsTimestamp=2026,8,7,10,18,0.486

[MainWindow]
MenuBar=Disabled
`)
	dolphinWant := `[General]
DoubleClickViewAction=go_back

[MainWindow]
MenuBar=Disabled
`
	if got := string(normalizeDolphinConfig(dolphin)); got != dolphinWant {
		t.Fatalf("normalized dolphin config mismatch\nwant:\n%s\ngot:\n%s", dolphinWant, got)
	}

	ark := []byte(`[ExtractDialog]
DirHistory[$e]=$HOME/Private/

[General]
LockSidebar=true
`)
	arkWant := `[General]
LockSidebar=true
`
	if got := string(normalizeArkConfig(ark)); got != arkWant {
		t.Fatalf("normalized Ark config mismatch\nwant:\n%s\ngot:\n%s", arkWant, got)
	}
}
