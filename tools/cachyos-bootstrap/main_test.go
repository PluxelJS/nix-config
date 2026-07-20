package main

import (
	"bytes"
	"io"
	"os"
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

	desktopFeatures := cfg.Profiles["desktop"].Features
	if !stringInSlice("localsend", desktopFeatures) {
		t.Fatal("desktop profile should enable the LocalSend feature")
	}
	if got := cfg.Packages.Features["localsend"]; len(got) != 1 || got[0] != "ufw" {
		t.Fatalf("LocalSend host dependencies = %v, want [ufw]", got)
	}
	if stringInSlice("ufw", cfg.Packages.Features["gui"]) {
		t.Fatal("UFW should follow the LocalSend feature, not the generic GUI feature")
	}
}

func TestDetectsLocalSendUFWRules(t *testing.T) {
	path := filepath.Join(t.TempDir(), "user.rules")
	rules := `### tuple ### allow udp 53317 0.0.0.0/0 any 0.0.0.0/0 LocalSend - in
-A ufw-user-input -p udp --dport 53317 -j ACCEPT -m comment --comment 'dapp_LocalSend'
### tuple ### allow tcp 53317 0.0.0.0/0 any 0.0.0.0/0 LocalSend - in
-A ufw-user-input -p tcp --dport 53317 -j ACCEPT -m comment --comment 'dapp_LocalSend'
`
	if err := os.WriteFile(path, []byte(rules), 0o644); err != nil {
		t.Fatal(err)
	}
	if !ufwRulesFileHasLocalSend(path) {
		t.Fatal("expected LocalSend TCP/UDP rules to be detected")
	}
}

func TestRejectsIncompleteLocalSendUFWRules(t *testing.T) {
	path := filepath.Join(t.TempDir(), "user.rules")
	if err := os.WriteFile(path, []byte("allow udp 53317 LocalSend\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if ufwRulesFileHasLocalSend(path) {
		t.Fatal("expected a UDP-only LocalSend rule to be rejected")
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
		"--with-flatpaks",
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
	if !opts.withFlatpaks {
		t.Fatal("expected --with-flatpaks to set withFlatpaks")
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
	for _, want := range []string{"bootstrap", "deps", "firewall", "flatpaks", "pull-gui-config", "cleanup", "verify"} {
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
