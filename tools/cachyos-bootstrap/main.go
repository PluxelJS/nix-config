package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/pelletier/go-toml/v2"
	"github.com/spf13/cobra"
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

type app struct {
	repo string
	cfg  config
}

type depOptions struct {
	apply           bool
	minimal         bool
	profile         string
	profileExplicit bool
}

type depResult struct {
	repoMissing      []string
	aurMissing       []string
	extrasMissing    []string
	extrasApplicable bool
	notes            []string
}

type bootstrapOptions struct {
	apply       bool
	profile     string
	flake       string
	minimal     bool
	installNix  bool
	installParu bool
	switchAfter bool
}

func main() {
	repo, err := findRepo()
	if err != nil {
		die(err)
	}

	cfg, err := loadConfig(filepath.Join(repo, "bootstrap", "cachyos.toml"))
	if err != nil {
		die(err)
	}
	if err := validateConfig(cfg); err != nil {
		die(err)
	}

	a := app{repo: repo, cfg: cfg}
	if err := a.newRootCommand().Execute(); err != nil {
		die(err)
	}
}

func findRepo() (string, error) {
	if repo := os.Getenv("AHDG_NIX_REPO"); repo != "" {
		return filepath.Abs(repo)
	}

	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return "", err
	}

	dir := filepath.Dir(exe)
	candidates := []string{
		filepath.Clean(filepath.Join(dir, "..", "..")),
		filepath.Clean(filepath.Join(dir, "..")),
	}
	if cwd, err := os.Getwd(); err == nil {
		candidates = append(candidates, cwd)
	}

	for _, candidate := range candidates {
		if fileExists(filepath.Join(candidate, "flake.nix")) && fileExists(filepath.Join(candidate, "bootstrap", "cachyos.toml")) {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("could not locate repo root from executable path %s; set AHDG_NIX_REPO", exe)
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

	for group, packages := range map[string][]pkgSpec{
		"repoPackages.base": cfg.RepoPackages.Base,
	} {
		if err := validatePackages(group, packages); err != nil {
			return err
		}
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

func (a app) newRootCommand() *cobra.Command {
	rootOpts := defaultBootstrapOptions()
	cmd := &cobra.Command{
		Use:           "cachyos-bootstrap",
		Short:         "Bootstrap and validate the CachyOS host for this Home Manager repo",
		SilenceUsage:  true,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) != 0 {
				return fmt.Errorf("unexpected arguments: %s", strings.Join(args, " "))
			}
			return a.runBootstrap(rootOpts)
		},
	}
	cmd.CompletionOptions.DisableDefaultCmd = true
	addBootstrapFlags(cmd, &rootOpts)
	cmd.AddCommand(a.newBootstrapCommand(), a.newDepsCommand(), a.newCleanupCommand(), a.newVerifyCommand())
	return cmd
}

func (a app) newBootstrapCommand() *cobra.Command {
	opts := defaultBootstrapOptions()
	cmd := &cobra.Command{
		Use:   "bootstrap",
		Short: "Run the fresh CachyOS setup flow",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) != 0 {
				return fmt.Errorf("unexpected arguments: %s", strings.Join(args, " "))
			}
			return a.runBootstrap(opts)
		},
	}
	addBootstrapFlags(cmd, &opts)
	return cmd
}

func (a app) newDepsCommand() *cobra.Command {
	opts := depOptions{}
	cmd := &cobra.Command{
		Use:   "deps [profile]",
		Short: "Check or install host runtime dependencies",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if cmd.Flags().Changed("profile") {
				opts.profileExplicit = true
			}
			if len(args) == 1 {
				opts.profile = args[0]
				opts.profileExplicit = true
			}
			a.fillDefaultDepProfile(&opts)
			_, err := a.checkDeps(opts)
			return err
		},
	}
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "install missing host runtime dependencies")
	cmd.Flags().BoolVar(&opts.minimal, "minimal", false, "skip desktop extras and Flatpak canaries")
	addLegacyRecommendedFlag(cmd)
	cmd.Flags().StringVar(&opts.profile, "profile", "", "deployment profile")
	return cmd
}

func (a app) newCleanupCommand() *cobra.Command {
	opts := cleanupOptions{}
	cmd := &cobra.Command{
		Use:   "cleanup",
		Short: "Remove pacman packages replaced by Nix or retired stacks",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return a.runCleanup(opts)
		},
	}
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "remove safe cleanup candidates")
	return cmd
}

func (a app) newVerifyCommand() *cobra.Command {
	opts := verifyOptions{}
	cmd := &cobra.Command{
		Use:   "verify [profile]",
		Short: "Validate the Home Manager migration result",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 1 {
				opts.profile = args[0]
			}
			return a.runVerify(opts)
		},
	}
	return cmd
}

func defaultBootstrapOptions() bootstrapOptions {
	return bootstrapOptions{
		profile:     "desktop",
		installNix:  true,
		installParu: true,
		switchAfter: true,
	}
}

func addBootstrapFlags(cmd *cobra.Command, opts *bootstrapOptions) {
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "install missing prerequisites and run Home Manager")
	cmd.Flags().StringVar(&opts.profile, "profile", opts.profile, "deployment profile")
	cmd.Flags().StringVar(&opts.flake, "flake", "", "flake output; default follows profile")
	cmd.Flags().BoolVar(&opts.minimal, "minimal", false, "skip desktop extras and Flatpak canaries")
	addLegacyRecommendedFlag(cmd)
	cmd.Flags().BoolVar(&opts.installNix, "install-nix", true, "install Nix when missing")
	cmd.Flags().BoolVar(&opts.installParu, "install-paru", true, "install paru when missing")
	cmd.Flags().BoolVar(&opts.switchAfter, "switch", true, "run Home Manager switch")
	cmd.Flags().BoolVar(&opts.installNix, "no-install-nix", true, "skip Nix installation/daemon setup")
	cmd.Flags().Lookup("no-install-nix").NoOptDefVal = "false"
	_ = cmd.Flags().MarkHidden("no-install-nix")
	cmd.Flags().BoolVar(&opts.installParu, "no-install-paru", true, "skip paru installation")
	cmd.Flags().Lookup("no-install-paru").NoOptDefVal = "false"
	_ = cmd.Flags().MarkHidden("no-install-paru")
	cmd.Flags().BoolVar(&opts.switchAfter, "no-switch", true, "do not run Home Manager switch")
	cmd.Flags().Lookup("no-switch").NoOptDefVal = "false"
	_ = cmd.Flags().MarkHidden("no-switch")
}

func addLegacyRecommendedFlag(cmd *cobra.Command) {
	var ignored bool
	cmd.Flags().BoolVar(&ignored, "with-recommended", false, "legacy no-op; desktop extras are included by default")
	_ = cmd.Flags().MarkHidden("with-recommended")
}

func (a app) runBootstrap(opts bootstrapOptions) error {
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
	}); err != nil {
		return err
	}

	if err := a.ensureFlatpakApps(opts); err != nil {
		return err
	}

	if opts.switchAfter {
		if err := a.runHomeManager(opts); err != nil {
			return err
		}
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

func (a app) checkDeps(opts depOptions) (depResult, error) {
	var result depResult
	features, err := a.featuresFor(opts.profile, opts.profileExplicit)
	if err != nil {
		return result, err
	}

	fmt.Printf("Profile: %s\nMode: %s\n", opts.profile, modeName(opts.apply))
	result.extrasApplicable = hasFeatureExtras(a.cfg.RepoPackages.FeatureExtras, features)
	if result.extrasApplicable {
		if opts.minimal {
			fmt.Println("Desktop extras: skip")
		} else {
			fmt.Println("Desktop extras: include")
		}
	}
	fmt.Println()

	for _, pkg := range a.cfg.RepoPackages.Base {
		result.ensureRepo(pkg, opts.apply)
	}

	featureNames := sortedKeys(features)
	for _, feature := range featureNames {
		for _, pkg := range a.cfg.RepoPackages.Features[feature] {
			result.ensureRepo(pkg, opts.apply)
		}
	}

	for _, pkg := range a.cfg.RepoPackages.Profiles[opts.profile] {
		result.ensureRepo(pkg, opts.apply)
	}

	if features["gui"] {
		for _, check := range a.cfg.DesktopCommands {
			if commandAnyExists(check.Commands) {
				pass("%s available via: %s (%s)", check.Label, existingCommands(check.Commands), check.Reason)
			} else {
				fail("%s missing; expected one of: %s (%s)", check.Label, strings.Join(check.Commands, " "), check.Reason)
				if check.AURPackage != "" {
					result.aurMissing = append(result.aurMissing, check.AURPackage)
				}
				if check.Note != "" {
					result.notes = append(result.notes, check.Note)
				}
			}
		}

		if a.cfg.Browser.Command != "" {
			if commandExists(a.cfg.Browser.Command) {
				pass("browser command `%s` available (%s)", a.cfg.Browser.Command, a.cfg.Browser.Reason)
			} else {
				warn("browser command `%s` missing (%s)", a.cfg.Browser.Command, a.cfg.Browser.Reason)
				if a.cfg.Browser.Note != "" {
					result.notes = append(result.notes, a.cfg.Browser.Note)
				}
			}
		}
	}

	if !opts.minimal {
		for _, feature := range featureNames {
			for _, pkg := range a.cfg.RepoPackages.FeatureExtras[feature] {
				result.ensureExtra(pkg)
			}
		}
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
	} else {
		result.printSummary(a.depApplyCommand(opts))
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

func hasFeatureExtras(extras map[string][]pkgSpec, features map[string]bool) bool {
	for feature, enabled := range features {
		if enabled && len(extras[feature]) > 0 {
			return true
		}
	}
	return false
}

func (r *depResult) ensureRepo(pkg pkgSpec, apply bool) {
	if pacmanPackageInstalled(pkg.Name) {
		pass("repo package `%s` installed (%s)", pkg.Name, pkg.Reason)
		return
	}
	fail("repo package `%s` missing (%s)", pkg.Name, pkg.Reason)
	r.repoMissing = append(r.repoMissing, pkg.Name)
}

func (r *depResult) ensureExtra(pkg pkgSpec) {
	if pacmanPackageInstalled(pkg.Name) {
		pass("desktop extra repo package `%s` installed (%s)", pkg.Name, pkg.Reason)
		return
	}
	warn("desktop extra repo package `%s` missing (%s)", pkg.Name, pkg.Reason)
	r.extrasMissing = append(r.extrasMissing, pkg.Name)
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

func (r depResult) printSummary(applyCommand string) {
	if !r.extrasApplicable {
		fmt.Printf(`
Summary:
  Required repo packages missing: %d
  Required AUR packages missing: %d

Apply packages:
  %s --apply
`, len(uniqueSorted(r.repoMissing)), len(uniqueSorted(r.aurMissing)), applyCommand)

		printList("Required repo packages to install:", r.repoMissing)
		printList("Required AUR packages to install:", r.aurMissing)
		return
	}

	fmt.Printf(`
Summary:
  Required repo packages missing: %d
  Required AUR packages missing: %d
  Desktop extra repo packages missing: %d

Apply required packages:
  %s --apply --minimal

Apply full profile packages:
  %s --apply
`, len(uniqueSorted(r.repoMissing)), len(uniqueSorted(r.aurMissing)), len(uniqueSorted(r.extrasMissing)), applyCommand, applyCommand)

	printList("Required repo packages to install:", r.repoMissing)
	printList("Required AUR packages to install:", r.aurMissing)
	printList("Desktop extra repo packages to install:", r.extrasMissing)
}

func (a app) ensureNix(opts bootstrapOptions) error {
	if commandExists("nix") {
		pass("nix command available")
	} else if opts.installNix {
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
	if !opts.installParu {
		warn("paru command missing and --no-install-paru was set")
		return nil
	}

	fail("paru command missing")
	if !opts.apply {
		return nil
	}

	if err := installPacmanPackage("base-devel", "required to build AUR packages", opts.apply); err != nil {
		return err
	}
	if err := installPacmanPackage("git", "required to fetch AUR package sources", opts.apply); err != nil {
		return err
	}
	if pacmanHasPackage("paru") {
		return installPacmanPackage("paru", "AUR helper", opts.apply)
	}

	tmp, err := os.MkdirTemp("", "ahdg-paru-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	dest := filepath.Join(tmp, "paru-bin")
	if err := run("git", "clone", "https://aur.archlinux.org/paru-bin.git", dest); err != nil {
		return err
	}
	return runInDir(dest, "makepkg", "-si", "--noconfirm")
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

func (a app) ensureFlatpakApps(opts bootstrapOptions) error {
	apps := a.cfg.Flatpaks[opts.profile]
	if len(apps) == 0 {
		return nil
	}
	if opts.minimal {
		warn("desktop Flatpak canaries for profile %q skipped by --minimal", opts.profile)
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
		args := append([]string{"install", "-y", "--or-update", "flathub"}, missing...)
		return run("flatpak", args...)
	}
	return nil
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
	return run(filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "verify", opts.profile)
}

func ensureFlathub(apply bool) error {
	if outputContainsLine("flatpak", []string{"remotes", "--columns=name"}, "flathub") {
		pass("Flatpak remote `flathub` configured")
		return nil
	}
	fail("Flatpak remote `flathub` missing")
	if apply {
		return run("flatpak", "remote-add", "--if-not-exists", "flathub", "https://flathub.org/repo/flathub.flatpakrepo")
	}
	return nil
}

func pacmanPackageInstalled(pkg string) bool {
	return commandOK("pacman", "-Q", pkg)
}

func pacmanHasPackage(pkg string) bool {
	return commandOK("pacman", "-Si", pkg)
}

func flatpakAppInstalled(appID string) bool {
	return commandOK("flatpak", "info", appID)
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func commandAnyExists(commands []string) bool {
	for _, cmd := range commands {
		if commandExists(cmd) {
			return true
		}
	}
	return false
}

func existingCommands(commands []string) string {
	var found []string
	for _, cmd := range commands {
		if commandExists(cmd) {
			found = append(found, cmd)
		}
	}
	return strings.Join(found, " ")
}

func commandOK(name string, args ...string) bool {
	cmd := exec.Command(name, args...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func run(name string, args ...string) error {
	fmt.Println("+ " + shellJoin(append([]string{name}, args...)))
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func runEnv(env []string, name string, args ...string) error {
	fmt.Println("+ " + shellJoin(append([]string{name}, args...)))
	cmd := exec.Command(name, args...)
	cmd.Env = env
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func runInDir(dir, name string, args ...string) error {
	fmt.Println("+ " + shellJoin(append([]string{name}, args...)))
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func outputContainsLine(name string, args []string, wanted string) bool {
	cmd := exec.Command(name, args...)
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(out), "\n") {
		if strings.TrimSpace(line) == wanted {
			return true
		}
	}
	return false
}

func groupExists(group string) bool {
	return commandOK("getent", "group", group)
}

func userInGroup(user, group string) bool {
	out, err := exec.Command("id", "-nG", user).Output()
	if err != nil {
		return false
	}
	for _, item := range strings.Fields(string(out)) {
		if item == group {
			return true
		}
	}
	return false
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func linesAsSet(text string) map[string]bool {
	result := make(map[string]bool)
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			result[line] = true
		}
	}
	return result
}

func sortedKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for key, enabled := range m {
		if enabled {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	return keys
}

func uniqueSorted(items []string) []string {
	seen := make(map[string]bool)
	var result []string
	for _, item := range items {
		item = strings.TrimSpace(item)
		if item == "" || seen[item] {
			continue
		}
		seen[item] = true
		result = append(result, item)
	}
	sort.Strings(result)
	return result
}

func printList(title string, items []string) {
	items = uniqueSorted(items)
	if len(items) == 0 {
		return
	}
	fmt.Println()
	fmt.Println(title)
	for _, item := range items {
		fmt.Printf("  %s\n", item)
	}
}

func shellJoin(args []string) string {
	quoted := make([]string, len(args))
	for i, arg := range args {
		quoted[i] = shellQuote(arg)
	}
	return strings.Join(quoted, " ")
}

func shellQuote(s string) string {
	if s == "" {
		return "''"
	}
	if strings.IndexFunc(s, func(r rune) bool {
		return !(r >= 'A' && r <= 'Z') &&
			!(r >= 'a' && r <= 'z') &&
			!(r >= '0' && r <= '9') &&
			!strings.ContainsRune("@%_+=:,./-", r)
	}) == -1 {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'"
}

func modeName(apply bool) string {
	if apply {
		return "apply"
	}
	return "check"
}

func pass(format string, args ...any) {
	fmt.Printf("[ok] "+format+"\n", args...)
}

func warn(format string, args ...any) {
	fmt.Printf("[warn] "+format+"\n", args...)
}

func fail(format string, args ...any) {
	fmt.Printf("[missing] "+format+"\n", args...)
}

func die(err error) {
	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	os.Exit(1)
}
