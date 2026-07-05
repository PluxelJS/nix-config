package main

import (
	"bytes"
	"io"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

func TestBundledConfigValidates(t *testing.T) {
	cfg, err := loadConfig(filepath.Join("..", "..", "bootstrap", "cachyos.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if err := validateConfig(cfg); err != nil {
		t.Fatal(err)
	}
}

func TestBootstrapFlags(t *testing.T) {
	opts := defaultBootstrapOptions()
	cmd := &cobra.Command{
		Use:           "test",
		SilenceUsage:  true,
		SilenceErrors: true,
		Run:           func(cmd *cobra.Command, args []string) {},
	}
	cmd.SetOut(io.Discard)
	cmd.SetErr(io.Discard)
	addBootstrapFlags(cmd, &opts)
	cmd.SetArgs([]string{
		"--apply",
		"--profile", "shell",
		"--no-install-nix",
		"--no-install-paru",
		"--no-switch",
	})
	err := cmd.Execute()
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

func TestRootHelpIncludesSubcommands(t *testing.T) {
	var out bytes.Buffer
	cmd := app{}.newRootCommand()
	cmd.SetOut(&out)
	cmd.SetErr(io.Discard)
	cmd.SetArgs([]string{"--help"})
	err := cmd.Execute()
	if err != nil {
		t.Fatal(err)
	}

	help := out.String()
	for _, want := range []string{"bootstrap", "deps", "cleanup", "verify"} {
		if !strings.Contains(help, want) {
			t.Fatalf("help output missing %q:\n%s", want, help)
		}
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
