package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type depOptions struct {
	apply           bool
	minimal         bool
	profile         string
	profileExplicit bool
	sudoReady       bool
}

type depResult struct {
	repoMissing      []string
	aurMissing       []string
	extrasMissing    []string
	groupsMissing    []string
	extrasApplicable bool
	notes            []string
}

func (a app) runBootstrap(opts bootstrapOptions) error {
	if opts.noFlatpaks && opts.withFlatpaks {
		return errors.New("--no-flatpaks and --with-flatpaks cannot be used together")
	}

	profile, ok := a.cfg.Profiles[opts.profile]
	if !ok {
		return fmt.Errorf("unsupported profile: %s", opts.profile)
	}
	if opts.flake == "" {
		opts.flake = profile.Flake
	}

	if !commandExists("pacman") {
		return errors.New("this bootstrap expects a pacman-based CachyOS/Arch host")
	}

	fmt.Printf("Bootstrap target:\n  repo:    %s\n  profile: %s\n  flake:   %s\n  mode:    %s\n\n",
		a.repo, opts.profile, opts.flake, modeName(opts.apply))

	if opts.apply {
		if err := requireSudo(); err != nil {
			return err
		}
	}

	if err := a.ensureNix(opts); err != nil {
		return err
	}
	if err := a.ensureParu(opts); err != nil {
		return err
	}

	fmt.Println()
	if _, err := a.checkDeps(depOptions{
		apply:           opts.apply,
		minimal:         opts.minimal,
		profile:         opts.profile,
		profileExplicit: true,
		sudoReady:       opts.apply,
	}); err != nil {
		return err
	}

	if !opts.noSwitch {
		if err := a.runHomeManager(opts); err != nil {
			return err
		}
	}

	if opts.noFlatpaks {
		warn("remote and local Flatpak app installs skipped by --no-flatpaks")
	} else if opts.withFlatpaks {
		if err := a.runFlatpaks(flatpakOptions{
			apply:   opts.apply,
			minimal: opts.minimal,
			profile: opts.profile,
		}); err != nil {
			return err
		}
	} else {
		warn("remote and local Flatpak app installs deferred; desktop base is applied first")
	}

	fmt.Printf("\nDesktop base flow complete.\n")
	if !opts.withFlatpaks && !opts.noFlatpaks && !opts.minimal && (len(a.cfg.Flatpaks[opts.profile]) > 0 || len(a.cfg.LocalFlatpaks[opts.profile]) > 0) {
		fmt.Printf("\nOptional Flatpak app catch-up:\n  %s\n",
			shellJoin([]string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "flatpaks", "--apply", "--profile", opts.profile}))
	}
	fmt.Printf("\nNext checks after reboot/login:\n  %s %s\n",
		shellJoin([]string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "verify"}), opts.profile)
	return nil
}

func (a app) fillDefaultDepProfile(opts *depOptions) {
	if opts.profile != "" {
		opts.profileExplicit = true
	}
	if opts.profile == "" {
		if data, err := os.ReadFile(filepath.Join(os.Getenv("HOME"), ".config", "ahdg", "profile")); err == nil {
			opts.profile = strings.TrimSpace(string(data))
		}
	}
	if opts.profile == "" {
		opts.profile = "desktop"
	}
}

func (a app) fillDefaultFlatpakProfile(opts *flatpakOptions) {
	if opts.profile == "" {
		if data, err := os.ReadFile(filepath.Join(os.Getenv("HOME"), ".config", "ahdg", "profile")); err == nil {
			opts.profile = strings.TrimSpace(string(data))
		}
	}
	if opts.profile == "" {
		opts.profile = "desktop"
	}
}

func (a app) checkDeps(opts depOptions) (depResult, error) {
	var result depResult
	features, err := a.featuresFor(opts.profile, opts.profileExplicit)
	if err != nil {
		return result, err
	}

	fmt.Printf("Profile: %s\nMode: %s\n", opts.profile, modeName(opts.apply))
	result.extrasApplicable = hasFeatureExtras(a.cfg.Packages.Extras, features)
	if result.extrasApplicable {
		if opts.minimal {
			fmt.Println("Desktop extras: skip")
		} else {
			fmt.Println("Desktop extras: include")
		}
	}
	fmt.Println()

	if opts.apply && !opts.sudoReady {
		if err := requireSudo(); err != nil {
			return result, err
		}
		opts.sudoReady = true
	}

	for _, pkg := range a.cfg.Packages.Base {
		result.ensureRepo(pkg)
	}

	featureNames := sortedKeys(features)
	for _, feature := range featureNames {
		for _, pkg := range a.cfg.Packages.Features[feature] {
			result.ensureRepo(pkg)
		}
	}

	for _, pkg := range a.cfg.Packages.Profiles[opts.profile] {
		result.ensureRepo(pkg)
	}

	if features["gui"] {
		for _, aurPackage := range a.cfg.AURPackages[opts.profile] {
			result.ensureAURPackage(aurPackage)
		}

		for _, aurPackage := range sortedStringKeys(a.cfg.AURCommands) {
			missing := missingCommands(a.cfg.AURCommands[aurPackage])
			if len(missing) == 0 {
				pass("AUR package `%s` commands available: %s", aurPackage, strings.Join(a.cfg.AURCommands[aurPackage], " "))
				continue
			}
			fail("AUR package `%s` missing commands: %s", aurPackage, strings.Join(missing, " "))
			result.aurMissing = append(result.aurMissing, aurPackage)
		}

		if a.cfg.Browser.Command != "" {
			if commandExists(a.cfg.Browser.Command) {
				pass("browser command `%s` available", a.cfg.Browser.Command)
			} else {
				warn("browser command `%s` missing", a.cfg.Browser.Command)
				if a.cfg.Browser.Note != "" {
					result.notes = append(result.notes, a.cfg.Browser.Note)
				}
			}
		}
	}

	if !opts.minimal {
		for _, feature := range featureNames {
			for _, pkg := range a.cfg.Packages.Extras[feature] {
				result.ensureExtra(pkg)
			}
		}
	}

	for _, group := range a.cfg.UserGroups[opts.profile] {
		result.ensureUserGroup(os.Getenv("USER"), group)
	}

	result.notes = uniqueSorted(result.notes)
	if len(result.notes) > 0 {
		fmt.Println()
		fmt.Println("Notes:")
		for _, note := range result.notes {
			fmt.Printf("  - %s\n", note)
		}
	}

	if opts.apply {
		if err := result.applyPackages(!opts.minimal); err != nil {
			return result, err
		}
		if err := a.applyUserGroups(opts.profile); err != nil {
			return result, err
		}
	} else {
		result.printSummary(a.depApplyCommand(opts))
	}

	if features["localsend"] {
		fmt.Println()
		if err := a.runFirewall(firewallOptions{apply: opts.apply, sudoReady: opts.sudoReady}); err != nil {
			return result, err
		}
	}

	return result, nil
}

func (a app) depApplyCommand(opts depOptions) string {
	args := []string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "deps"}
	if opts.profileExplicit {
		args = append(args, "--profile", opts.profile)
	}
	return shellJoin(args)
}

func (a app) featuresFor(profile string, explicit bool) (map[string]bool, error) {
	if !explicit {
		path := filepath.Join(os.Getenv("HOME"), ".config", "ahdg", "enabled-features")
		if data, err := os.ReadFile(path); err == nil {
			return linesAsSet(string(data)), nil
		}
	}

	profileCfg, ok := a.cfg.Profiles[profile]
	if !ok {
		return nil, fmt.Errorf("unsupported profile: %s", profile)
	}
	features := make(map[string]bool)
	for _, feature := range profileCfg.Features {
		features[feature] = true
	}
	return features, nil
}

func hasFeatureExtras(extras map[string][]string, features map[string]bool) bool {
	for feature, enabled := range features {
		if enabled && len(extras[feature]) > 0 {
			return true
		}
	}
	return false
}

func (r *depResult) ensureRepo(pkg string) {
	if pacmanPackageInstalled(pkg) {
		pass("repo package `%s` installed", pkg)
		return
	}
	fail("repo package `%s` missing", pkg)
	r.repoMissing = append(r.repoMissing, pkg)
}

func (r *depResult) ensureExtra(pkg string) {
	if pacmanPackageInstalled(pkg) {
		pass("desktop extra repo package `%s` installed", pkg)
		return
	}
	warn("desktop extra repo package `%s` missing", pkg)
	r.extrasMissing = append(r.extrasMissing, pkg)
}

func (r *depResult) ensureAURPackage(pkg string) {
	if pacmanPackageInstalled(pkg) {
		pass("AUR package `%s` installed", pkg)
		return
	}
	fail("AUR package `%s` missing", pkg)
	r.aurMissing = append(r.aurMissing, pkg)
}

func (r *depResult) ensureUserGroup(user, group string) {
	if !groupExists(group) {
		fail("user group `%s` missing", group)
		r.groupsMissing = append(r.groupsMissing, group)
		return
	}
	if userInGroup(user, group) {
		pass("%s is already in `%s`", user, group)
		return
	}
	fail("%s is not in user group `%s`", user, group)
	r.groupsMissing = append(r.groupsMissing, group)
}

func (r depResult) applyPackages(includeExtras bool) error {
	repoMissing := uniqueSorted(r.repoMissing)
	extrasMissing := uniqueSorted(r.extrasMissing)
	aurMissing := uniqueSorted(r.aurMissing)

	if len(repoMissing) > 0 {
		fmt.Println("Installing missing required repo packages...")
		if err := run("sudo", append([]string{"pacman", "-S", "--needed"}, repoMissing...)...); err != nil {
			return err
		}
	} else {
		fmt.Println("No required repo packages missing.")
	}

	if includeExtras && len(extrasMissing) > 0 {
		fmt.Println()
		fmt.Println("Installing missing desktop extra repo packages...")
		if err := run("sudo", append([]string{"pacman", "-S", "--needed"}, extrasMissing...)...); err != nil {
			return err
		}
	} else if len(extrasMissing) > 0 {
		fmt.Println()
		fmt.Println("Desktop extra repo packages left untouched:")
		for _, pkg := range extrasMissing {
			fmt.Printf("  %s\n", pkg)
		}
		fmt.Println("Re-run without --minimal if you want them installed too.")
	}

	if len(aurMissing) > 0 {
		fmt.Println()
		if !commandExists("paru") {
			return fmt.Errorf("missing required AUR packages and no paru command is available: %s; run bootstrap/cachyos.sh --apply", strings.Join(aurMissing, ", "))
		}
		fmt.Println("Installing missing required AUR packages...")
		if err := run("paru", append([]string{"-S", "--needed"}, aurMissing...)...); err != nil {
			return err
		}
	}
	return nil
}

func (a app) applyUserGroups(profile string) error {
	groups := uniqueSorted(a.cfg.UserGroups[profile])
	if len(groups) == 0 {
		return nil
	}

	user := os.Getenv("USER")
	var missing []string
	for _, group := range groups {
		if !groupExists(group) {
			missing = append(missing, group)
			continue
		}
		if userInGroup(user, group) {
			pass("%s is already in `%s`", user, group)
			continue
		}
		if err := run("sudo", "usermod", "-aG", group, user); err != nil {
			return err
		}
		warn("log out and back in before using devices that require `%s`", group)
	}
	if len(missing) > 0 {
		return fmt.Errorf("required user groups are still missing after package install: %s", strings.Join(missing, ", "))
	}
	return nil
}

func (r depResult) printSummary(applyCommand string) {
	if !r.extrasApplicable {
		fmt.Printf(`
Summary:
  Required repo packages missing: %d
  Required AUR packages missing: %d
  Required user groups missing: %d

Apply packages:
  %s --apply
`, len(uniqueSorted(r.repoMissing)), len(uniqueSorted(r.aurMissing)), len(uniqueSorted(r.groupsMissing)), applyCommand)

		printList("Required repo packages to install:", r.repoMissing)
		printList("Required AUR packages to install:", r.aurMissing)
		printList("Required user groups to join:", r.groupsMissing)
		return
	}

	fmt.Printf(`
Summary:
  Required repo packages missing: %d
  Required AUR packages missing: %d
  Required user groups missing: %d
  Desktop extra repo packages missing: %d

Apply required packages:
  %s --apply --minimal

Apply full profile packages:
  %s --apply
`, len(uniqueSorted(r.repoMissing)), len(uniqueSorted(r.aurMissing)), len(uniqueSorted(r.groupsMissing)), len(uniqueSorted(r.extrasMissing)), applyCommand, applyCommand)

	printList("Required repo packages to install:", r.repoMissing)
	printList("Required AUR packages to install:", r.aurMissing)
	printList("Required user groups to join:", r.groupsMissing)
	printList("Desktop extra repo packages to install:", r.extrasMissing)
}

func (a app) ensureNix(opts bootstrapOptions) error {
	if commandExists("nix") {
		pass("nix command available")
	} else if !opts.noInstallNix {
		fail("nix command missing")
		if opts.apply {
			if err := installPacmanPackage("nix", "Nix daemon and CLI", opts.apply); err != nil {
				return err
			}
		}
	} else {
		warn("nix command missing and --no-install-nix was set")
	}

	if opts.apply && commandExists("systemctl") {
		if err := run("sudo", "systemctl", "enable", "--now", "nix-daemon.service"); err != nil {
			return err
		}
	}

	if opts.apply && groupExists("nix-users") {
		user := os.Getenv("USER")
		if userInGroup(user, "nix-users") {
			pass("%s is already in nix-users", user)
		} else {
			if err := run("sudo", "usermod", "-aG", "nix-users", user); err != nil {
				return err
			}
			warn("log out and back in if nix-daemon rejects builds for this user")
		}
	}
	return nil
}

func (a app) ensureParu(opts bootstrapOptions) error {
	if commandExists("paru") {
		pass("paru command available")
		return nil
	}
	if opts.noInstallParu {
		warn("paru command missing and --no-install-paru was set")
		return nil
	}

	fail("paru command missing")
	if !opts.apply {
		return nil
	}

	if pacmanHasPackage("paru") {
		return installPacmanPackage("paru", "AUR helper", opts.apply)
	}

	return errors.New("paru is missing and no trusted repo package is available; enable the CachyOS repo package first")
}

func installPacmanPackage(pkg, reason string, apply bool) error {
	if pacmanPackageInstalled(pkg) {
		pass("pacman package `%s` installed (%s)", pkg, reason)
		return nil
	}
	fail("pacman package `%s` missing (%s)", pkg, reason)
	if apply {
		return run("sudo", "pacman", "-S", "--needed", pkg)
	}
	return nil
}

func (a app) runFlatpaks(opts flatpakOptions) error {
	if _, ok := a.cfg.Profiles[opts.profile]; !ok {
		return fmt.Errorf("unsupported profile: %s", opts.profile)
	}

	fmt.Printf("Flatpak target:\n  profile: %s\n  mode:    %s\n\n", opts.profile, modeName(opts.apply))
	bootstrapOpts := bootstrapOptions{
		apply:   opts.apply,
		minimal: opts.minimal,
		profile: opts.profile,
	}
	if err := a.ensureFlatpakApps(bootstrapOpts); err != nil {
		return err
	}
	if err := a.ensureLocalFlatpakApps(bootstrapOpts); err != nil {
		return err
	}
	return nil
}

func (a app) ensureFlatpakApps(opts bootstrapOptions) error {
	apps := a.cfg.Flatpaks[opts.profile]
	if len(apps) == 0 {
		return nil
	}
	if opts.minimal {
		warn("desktop Flatpak apps for profile %q skipped by --minimal", opts.profile)
		return nil
	}
	if !commandExists("flatpak") {
		warn("flatpak command missing; runtime dependency step must install it before desktop Flatpaks can be applied")
		return nil
	}

	if err := ensureFlathub(opts.apply); err != nil {
		return err
	}

	var missing []string
	for _, appID := range apps {
		if flatpakAppInstalled(appID) {
			pass("Flatpak app `%s` installed", appID)
		} else {
			fail("Flatpak app `%s` missing", appID)
			missing = append(missing, appID)
		}
	}

	if opts.apply && len(missing) > 0 {
		args := append([]string{"--user", "install", "-y", "--or-update", "flathub"}, missing...)
		return run("flatpak", args...)
	}
	return nil
}

func (a app) ensureLocalFlatpakApps(opts bootstrapOptions) error {
	apps := a.cfg.LocalFlatpaks[opts.profile]
	if len(apps) == 0 {
		return nil
	}
	if opts.minimal {
		warn("local desktop Flatpaks for profile %q skipped by --minimal", opts.profile)
		return nil
	}
	if !commandExists("flatpak") {
		warn("flatpak command missing; runtime dependency step must install it before local Flatpaks can be applied")
		return nil
	}

	var missing []string
	for _, appID := range apps {
		if flatpakAppInstalled(appID) {
			pass("local Flatpak app `%s` installed", appID)
		} else {
			fail("local Flatpak app `%s` missing", appID)
			missing = append(missing, appID)
		}
	}

	if opts.apply {
		for _, appID := range missing {
			if err := a.installLocalFlatpak(appID); err != nil {
				return err
			}
		}
	}
	return nil
}

func (a app) installLocalFlatpak(appID string) error {
	switch appID {
	case "io.github.trumank.CodeStudio":
		installer := filepath.Join(a.repo, "bootstrap", "codestudio", "install-code-studio.sh")
		return run("bash", installer, a.repo)
	default:
		return fmt.Errorf("no local Flatpak installer registered for %s", appID)
	}
}

func (a app) runHomeManager(opts bootstrapOptions) error {
	flakeRef := fmt.Sprintf("%s#%s", a.repo, opts.flake)
	if !opts.apply {
		fmt.Printf("\nHome Manager switch command:\n  nix run github:nix-community/home-manager -- switch --flake %s -b pre-nix\n", flakeRef)
		return nil
	}

	env := os.Environ()
	env = append(env, "NIX_CONFIG=experimental-features = nix-command flakes\naccept-flake-config = true")
	if err := runEnv(env, "nix", "run", "github:nix-community/home-manager", "--", "switch", "--flake", flakeRef, "-b", "pre-nix"); err != nil {
		return err
	}
	return nil
}

func ensureFlathub(apply bool) error {
	if outputContainsLine("flatpak", []string{"remotes", "--user", "--columns=name"}, "flathub") {
		pass("user Flatpak remote `flathub` configured")
		return nil
	}
	fail("user Flatpak remote `flathub` missing")
	if apply {
		return run("flatpak", "--user", "remote-add", "--if-not-exists", "flathub", "https://flathub.org/repo/flathub.flatpakrepo")
	}
	return nil
}

func requireSudo() error {
	if !commandExists("sudo") {
		return errors.New("sudo command missing; install and configure sudo first, then re-run with --apply")
	}
	fmt.Println("Preparing sudo credentials...")
	if err := run("sudo", "-v"); err != nil {
		return fmt.Errorf("sudo authentication failed; run `sudo -v` first or configure sudo for this user: %w", err)
	}
	return nil
}
