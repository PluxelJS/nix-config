package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/pelletier/go-toml/v2"
)

type config struct {
	Profiles      map[string]profileConfig `toml:"profiles"`
	Packages      packageConfig            `toml:"packages"`
	AURCommands   map[string][]string      `toml:"aurCommands"`
	AURPackages   map[string][]string      `toml:"aurPackages"`
	Browser       browserCheck             `toml:"browser"`
	Flatpaks      map[string][]string      `toml:"flatpaks"`
	LocalFlatpaks map[string][]string      `toml:"localFlatpaks"`
}

type profileConfig struct {
	Flake    string   `toml:"flake"`
	Features []string `toml:"features"`
}

type packageConfig struct {
	Base     []string            `toml:"base"`
	Features map[string][]string `toml:"features"`
	Profiles map[string][]string `toml:"profiles"`
	Extras   map[string][]string `toml:"extras"`
}

type browserCheck struct {
	Command string `toml:"command"`
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

	if err := validateItems("packages.base", cfg.Packages.Base); err != nil {
		return err
	}
	for feature, packages := range cfg.Packages.Features {
		if err := validateItems("packages.features."+feature, packages); err != nil {
			return err
		}
	}
	for profile, packages := range cfg.Packages.Profiles {
		if _, ok := cfg.Profiles[profile]; !ok {
			return fmt.Errorf("packages.profiles references unknown profile %q", profile)
		}
		if err := validateItems("packages.profiles."+profile, packages); err != nil {
			return err
		}
	}
	for feature, packages := range cfg.Packages.Extras {
		if err := validateItems("packages.extras."+feature, packages); err != nil {
			return err
		}
	}

	for aurPackage, commands := range cfg.AURCommands {
		if aurPackage == "" {
			return errors.New("aurCommands contains an empty package name")
		}
		if err := validateItems("aurCommands."+aurPackage, commands); err != nil {
			return err
		}
	}

	for profile, packages := range cfg.AURPackages {
		if _, ok := cfg.Profiles[profile]; !ok {
			return fmt.Errorf("aurPackages references unknown profile %q", profile)
		}
		if err := validateItems("aurPackages."+profile, packages); err != nil {
			return err
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
	for profile, apps := range cfg.LocalFlatpaks {
		if _, ok := cfg.Profiles[profile]; !ok {
			return fmt.Errorf("localFlatpaks references unknown profile %q", profile)
		}
		for _, appID := range apps {
			if appID == "" {
				return fmt.Errorf("localFlatpaks.%s contains an empty app id", profile)
			}
		}
	}
	return nil
}

func validateItems(group string, items []string) error {
	for index, item := range items {
		if item == "" {
			return fmt.Errorf("%s[%d] is empty", group, index)
		}
	}
	return nil
}
