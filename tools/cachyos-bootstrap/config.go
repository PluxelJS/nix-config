package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/pelletier/go-toml/v2"
)

type config struct {
	Profiles        map[string]profileConfig `toml:"profiles"`
	RepoPackages    repoPackages             `toml:"repoPackages"`
	DesktopCommands []commandCheck           `toml:"desktopCommands"`
	Browser         browserCheck             `toml:"browser"`
	Flatpaks        map[string][]string      `toml:"flatpaks"`
}

type profileConfig struct {
	Flake    string   `toml:"flake"`
	Features []string `toml:"features"`
}

type repoPackages struct {
	Base          []pkgSpec            `toml:"base"`
	Features      map[string][]pkgSpec `toml:"features"`
	Profiles      map[string][]pkgSpec `toml:"profiles"`
	FeatureExtras map[string][]pkgSpec `toml:"featureExtras"`
}

type pkgSpec struct {
	Name   string `toml:"name"`
	Reason string `toml:"reason"`
}

type commandCheck struct {
	Label      string   `toml:"label"`
	Reason     string   `toml:"reason"`
	Commands   []string `toml:"commands"`
	AURPackage string   `toml:"aurPackage"`
	Note       string   `toml:"note"`
}

type browserCheck struct {
	Command string `toml:"command"`
	Reason  string `toml:"reason"`
	Note    string `toml:"note"`
}

func loadConfig(path string) (config, error) {
	var cfg config
	data, err := os.ReadFile(path)
	if err != nil {
		return cfg, err
	}
	if err := toml.Unmarshal(data, &cfg); err != nil {
		return cfg, err
	}
	return cfg, nil
}

func validateConfig(cfg config) error {
	if len(cfg.Profiles) == 0 {
		return errors.New("bootstrap config has no profiles")
	}

	for name, profile := range cfg.Profiles {
		if name == "" {
			return errors.New("bootstrap config contains an empty profile name")
		}
		if profile.Flake == "" {
			return fmt.Errorf("profile %q has an empty flake attribute", name)
		}
		for _, feature := range profile.Features {
			if feature == "" {
				return fmt.Errorf("profile %q contains an empty feature", name)
			}
		}
	}

	if err := validatePackages("repoPackages.base", cfg.RepoPackages.Base); err != nil {
		return err
	}
	for feature, packages := range cfg.RepoPackages.Features {
		if err := validatePackages("repoPackages.features."+feature, packages); err != nil {
			return err
		}
	}
	for profile, packages := range cfg.RepoPackages.Profiles {
		if _, ok := cfg.Profiles[profile]; !ok {
			return fmt.Errorf("repoPackages.profiles references unknown profile %q", profile)
		}
		if err := validatePackages("repoPackages.profiles."+profile, packages); err != nil {
			return err
		}
	}
	for feature, packages := range cfg.RepoPackages.FeatureExtras {
		if err := validatePackages("repoPackages.featureExtras."+feature, packages); err != nil {
			return err
		}
	}

	for index, check := range cfg.DesktopCommands {
		if check.Label == "" {
			return fmt.Errorf("desktopCommands[%d] has an empty label", index)
		}
		if len(check.Commands) == 0 {
			return fmt.Errorf("desktopCommands[%d] has no commands", index)
		}
		for _, command := range check.Commands {
			if command == "" {
				return fmt.Errorf("desktopCommands[%d] contains an empty command", index)
			}
		}
	}

	for profile, apps := range cfg.Flatpaks {
		if _, ok := cfg.Profiles[profile]; !ok {
			return fmt.Errorf("flatpaks references unknown profile %q", profile)
		}
		for _, appID := range apps {
			if appID == "" {
				return fmt.Errorf("flatpaks.%s contains an empty app id", profile)
			}
		}
	}
	return nil
}

func validatePackages(group string, packages []pkgSpec) error {
	for index, pkg := range packages {
		if pkg.Name == "" {
			return fmt.Errorf("%s[%d] has an empty package name", group, index)
		}
	}
	return nil
}
