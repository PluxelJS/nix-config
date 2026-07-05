package main

import (
	"path/filepath"
	"testing"
)

func TestBundledConfigValidates(t *testing.T) {
	cfg, err := loadConfig(filepath.Join("..", "..", "bootstrap", "cachyos.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err := validateConfig(cfg); err != nil {
		t.Fatal(err)
	}
}

func TestBootstrapOptionCompatibilityFlags(t *testing.T) {
	opts, err := parseBootstrapOptions([]string{
		"--apply",
		"--profile", "shell",
		"--no-install-nix",
		"--no-install-paru",
		"--no-switch",
	})
	if err != nil {
		t.Fatal(err)
	}

	if !opts.apply {
		t.Fatal("expected apply mode")
	}
	if opts.profile != "shell" {
		t.Fatalf("profile = %q, want shell", opts.profile)
	}
	if opts.installNix {
		t.Fatal("expected --no-install-nix to clear installNix")
	}
	if opts.installParu {
		t.Fatal("expected --no-install-paru to clear installParu")
	}
	if opts.switchAfter {
		t.Fatal("expected --no-switch to clear switchAfter")
	}
}

func TestDepProfilePositionalCompatibility(t *testing.T) {
	app := app{}
	opts, err := app.parseDepOptions([]string{"container"})
	if err != nil {
		t.Fatal(err)
	}
	if opts.profile != "container" {
		t.Fatalf("profile = %q, want container", opts.profile)
	}
	if !opts.profileExplicit {
		t.Fatal("expected positional profile to be explicit")
	}
}

func TestShellQuote(t *testing.T) {
	cases := map[string]string{
		"":                "''",
		"simple":          "simple",
		"/path/with-dash": "/path/with-dash",
		"has space":       "'has space'",
		"has'quote":       "'has'\"'\"'quote'",
	}

	for input, want := range cases {
		if got := shellQuote(input); got != want {
			t.Fatalf("shellQuote(%q) = %q, want %q", input, got, want)
		}
	}
}
