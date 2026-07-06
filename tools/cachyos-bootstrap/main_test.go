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
		"--no-flatpaks",
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
	if !opts.noFlatpaks {
		t.Fatal("expected --no-flatpaks to set noFlatpaks")
	}
	if !opts.noInstallNix {
		t.Fatal("expected --no-install-nix to set noInstallNix")
	}
	if !opts.noInstallParu {
		t.Fatal("expected --no-install-paru to set noInstallParu")
	}
	if !opts.noSwitch {
		t.Fatal("expected --no-switch to set noSwitch")
	}
}

func TestBootstrapMinimalFlag(t *testing.T) {
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
	cmd.SetArgs([]string{"--minimal"})
	err := cmd.Execute()
	if err != nil {
		t.Fatal(err)
	}

	if !opts.minimal {
		t.Fatal("expected --minimal to enable minimal mode")
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
