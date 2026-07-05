package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type config struct {
	Profiles            map[string]profileConfig `json:"profiles"`
	RepoPackages        repoPackages             `json:"repoPackages"`
	DesktopCommands     []commandCheck           `json:"desktopCommands"`
	Browser             browserCheck             `json:"browser"`
	RecommendedFlatpaks map[string][]string      `json:"recommendedFlatpaks"`
}

type profileConfig struct {
	Flake    string   `json:"flake"`
	Features []string `json:"features"`
}

type repoPackages struct {
	Base                []pkgSpec            `json:"base"`
	Features            map[string][]pkgSpec `json:"features"`
	Profiles            map[string][]pkgSpec `json:"profiles"`
	RecommendedFeatures map[string][]pkgSpec `json:"recommendedFeatures"`
}

type pkgSpec struct {
	Name   string `json:"name"`
	Reason string `json:"reason"`
}

type commandCheck struct {
	Label      string   `json:"label"`
	Reason     string   `json:"reason"`
	Commands   []string `json:"commands"`
	AURPackage string   `json:"aurPackage"`
	Note       string   `json:"note"`
}

type browserCheck struct {
	Command string `json:"command"`
	Reason  string `json:"reason"`
	Note    string `json:"note"`
}

type app struct {
	repo string
	cfg  config
}

type depOptions struct {
	apply              bool
	includeRecommended bool
	profile            string
	profileExplicit    bool
}

type depResult struct {
	repoMissing        []string
	aurMissing         []string
	recommendedMissing []string
	notes              []string
}

type bootstrapOptions struct {
	apply              bool
	profile            string
	flake              string
	includeRecommended bool
	installNix         bool
	installParu        bool
	switchAfter        bool
}

func main() {
	repo, err := findRepo()
	if err != nil {
		die(err)
	}

	cfg, err := loadConfig(filepath.Join(repo, "bootstrap", "cachyos.json"))
	if err != nil {
		die(err)
	}
	if err := validateConfig(cfg); err != nil {
		die(err)
	}

	a := app{repo: repo, cfg: cfg}

	args := os.Args[1:]
	cmd := "bootstrap"
	if len(args) > 0 {
		switch args[0] {
		case "bootstrap", "deps", "cleanup", "verify":
			cmd = args[0]
			args = args[1:]
		case "-h", "--help":
			printTopUsage()
			return
		}
	}

	var runErr error
	switch cmd {
	case "bootstrap":
		runErr = a.runBootstrap(args)
	case "deps":
		runErr = a.runDeps(args)
	case "cleanup":
		runErr = a.runCleanup(args)
	case "verify":
		runErr = a.runVerify(args)
	default:
		runErr = fmt.Errorf("unknown command: %s", cmd)
	}
	if runErr != nil {
		if errors.Is(runErr, flag.ErrHelp) {
			return
		}
		die(runErr)
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
		if fileExists(filepath.Join(candidate, "flake.nix")) && fileExists(filepath.Join(candidate, "bootstrap", "cachyos.json")) {
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
	if err := json.Unmarshal(data, &cfg); err != nil {
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
	for feature, packages := range cfg.RepoPackages.RecommendedFeatures {
		if err := validatePackages("repoPackages.recommendedFeatures."+feature, packages); err != nil {
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

	for profile, apps := range cfg.RecommendedFlatpaks {
		if _, ok := cfg.Profiles[profile]; !ok {
			return fmt.Errorf("recommendedFlatpaks references unknown profile %q", profile)
		}
		for _, appID := range apps {
			if appID == "" {
				return fmt.Errorf("recommendedFlatpaks.%s contains an empty app id", profile)
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

func (a app) runBootstrap(args []string) error {
	opts, err := parseBootstrapOptions(args)
	if err != nil {
		return err
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

	if err := a.ensureNix(opts); err != nil {
		return err
	}
	if err := a.ensureParu(opts); err != nil {
		return err
	}

	fmt.Println()
	_, err = a.checkDeps(depOptions{
		apply:              opts.apply,
		includeRecommended: opts.includeRecommended,
		profile:            opts.profile,
		profileExplicit:    true,
	})
	if err != nil {
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

func (a app) runDeps(args []string) error {
	opts, err := a.parseDepOptions(args)
	if err != nil {
		return err
	}
	_, err = a.checkDeps(opts)
	return err
}

func parseBootstrapOptions(args []string) (bootstrapOptions, error) {
	opts := bootstrapOptions{
		profile:     "desktop",
		installNix:  true,
		installParu: true,
		switchAfter: true,
	}

	fs := flag.NewFlagSet("bootstrap", flag.ContinueOnError)
	fs.BoolVar(&opts.apply, "apply", false, "install missing prerequisites and run Home Manager")
	fs.StringVar(&opts.profile, "profile", opts.profile, "deployment profile")
	fs.StringVar(&opts.flake, "flake", "", "flake output")
	fs.BoolVar(&opts.includeRecommended, "with-recommended", false, "include recommended desktop packages and Flatpak apps")
	fs.BoolVar(&opts.installNix, "install-nix", true, "install Nix when missing")
	fs.BoolVar(&opts.installParu, "install-paru", true, "install paru when missing")
	fs.BoolVar(&opts.switchAfter, "switch", true, "run Home Manager switch")

	rewritten := make([]string, 0, len(args))
	for _, arg := range args {
		switch arg {
		case "--no-install-nix":
			rewritten = append(rewritten, "--install-nix=false")
		case "--no-install-paru":
			rewritten = append(rewritten, "--install-paru=false")
		case "--no-switch":
			rewritten = append(rewritten, "--switch=false")
		default:
			rewritten = append(rewritten, arg)
		}
	}

	fs.Usage = printBootstrapUsage
	if err := fs.Parse(rewritten); err != nil {
		return opts, err
	}
	if fs.NArg() != 0 {
		return opts, fmt.Errorf("unexpected arguments: %s", strings.Join(fs.Args(), " "))
	}
	return opts, nil
}

func (a app) parseDepOptions(args []string) (depOptions, error) {
	opts := depOptions{}
	fs := flag.NewFlagSet("deps", flag.ContinueOnError)
	fs.BoolVar(&opts.apply, "apply", false, "install missing runtime dependencies")
	fs.BoolVar(&opts.includeRecommended, "with-recommended", false, "include recommended desktop packages")
	fs.StringVar(&opts.profile, "profile", "", "deployment profile")
	fs.Usage = printDepsUsage
	if err := fs.Parse(args); err != nil {
		return opts, err
	}

	if opts.profile != "" {
		opts.profileExplicit = true
	}
	if fs.NArg() > 0 {
		if fs.NArg() > 1 {
			return opts, fmt.Errorf("unexpected arguments: %s", strings.Join(fs.Args()[1:], " "))
		}
		opts.profile = fs.Arg(0)
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
	return opts, nil
}

func (a app) checkDeps(opts depOptions) (depResult, error) {
	var result depResult
	features, err := a.featuresFor(opts.profile, opts.profileExplicit)
	if err != nil {
		return result, err
	}

	fmt.Printf("Profile: %s\nMode: %s\n", opts.profile, modeName(opts.apply))
	if opts.includeRecommended {
		fmt.Println("Recommended packages: include in apply mode")
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

	for _, feature := range featureNames {
		for _, pkg := range a.cfg.RepoPackages.RecommendedFeatures[feature] {
			result.ensureRecommended(pkg)
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
		if err := result.applyPackages(opts.includeRecommended); err != nil {
			return result, err
		}
	} else {
		result.printSummary(shellJoin([]string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "deps"}))
	}

	return result, nil
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

func (r *depResult) ensureRepo(pkg pkgSpec, apply bool) {
	if pacmanPackageInstalled(pkg.Name) {
		pass("repo package `%s` installed (%s)", pkg.Name, pkg.Reason)
		return
	}
	fail("repo package `%s` missing (%s)", pkg.Name, pkg.Reason)
	r.repoMissing = append(r.repoMissing, pkg.Name)
}

func (r *depResult) ensureRecommended(pkg pkgSpec) {
	if pacmanPackageInstalled(pkg.Name) {
		pass("recommended repo package `%s` installed (%s)", pkg.Name, pkg.Reason)
		return
	}
	warn("recommended repo package `%s` missing (%s)", pkg.Name, pkg.Reason)
	r.recommendedMissing = append(r.recommendedMissing, pkg.Name)
}

func (r depResult) applyPackages(includeRecommended bool) error {
	repoMissing := uniqueSorted(r.repoMissing)
	recommendedMissing := uniqueSorted(r.recommendedMissing)
	aurMissing := uniqueSorted(r.aurMissing)

	if len(repoMissing) > 0 {
		fmt.Println("Installing missing required repo packages...")
		if err := run("sudo", append([]string{"pacman", "-S", "--needed"}, repoMissing...)...); err != nil {
			return err
		}
	} else {
		fmt.Println("No required repo packages missing.")
	}

	if includeRecommended && len(recommendedMissing) > 0 {
		fmt.Println()
		fmt.Println("Installing missing recommended repo packages...")
		if err := run("sudo", append([]string{"pacman", "-S", "--needed"}, recommendedMissing...)...); err != nil {
			return err
		}
	} else if len(recommendedMissing) > 0 {
		fmt.Println()
		fmt.Println("Recommended repo packages left untouched:")
		for _, pkg := range recommendedMissing {
			fmt.Printf("  %s\n", pkg)
		}
		fmt.Println("Re-run with --with-recommended if you want them installed too.")
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
	fmt.Printf(`
Summary:
  Required repo packages missing: %d
  Required AUR packages missing: %d
  Recommended repo packages missing: %d

Apply required packages:
  %s --apply

Apply required + recommended packages:
  %s --apply --with-recommended
`, len(uniqueSorted(r.repoMissing)), len(uniqueSorted(r.aurMissing)), len(uniqueSorted(r.recommendedMissing)), applyCommand, applyCommand)

	printList("Required repo packages to install:", r.repoMissing)
	printList("Required AUR packages to install:", r.aurMissing)
	printList("Recommended repo packages to consider:", r.recommendedMissing)
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
	apps := a.cfg.RecommendedFlatpaks[opts.profile]
	if len(apps) == 0 {
		return nil
	}
	if !opts.includeRecommended {
		warn("recommended Flatpak apps for profile %q skipped; pass --with-recommended to install them", opts.profile)
		return nil
	}
	if !commandExists("flatpak") {
		warn("flatpak command missing; runtime dependency step must install it before recommended Flatpaks can be applied")
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

func printTopUsage() {
	fmt.Println(`Usage: cachyos-bootstrap <bootstrap|deps|cleanup|verify> [options]

Commands:
  bootstrap   fresh CachyOS setup flow
  deps        check or install host runtime dependencies
  cleanup     remove pacman packages replaced by Nix or retired stacks
  verify      validate the Home Manager migration result`)
}

func printBootstrapUsage() {
	fmt.Println(`Usage: cachyos-bootstrap bootstrap [--apply] [--profile desktop|shell|container] [--with-recommended]

Options:
  --apply              install missing prerequisites and run Home Manager
  --profile NAME       deployment profile; default: desktop
  --flake ATTR         flake output; default follows profile
  --with-recommended   include recommended desktop packages and Flatpak apps
  --no-install-nix     skip Nix installation/daemon setup
  --no-install-paru    skip paru installation
  --no-switch          do not run Home Manager switch`)
}

func printDepsUsage() {
	fmt.Println(`Usage: cachyos-bootstrap deps [--apply] [--profile desktop|shell|container] [--with-recommended]

Options:
  --apply              install missing host runtime dependencies
  --profile NAME       deployment profile; default from ~/.config/ahdg/profile or desktop
  --with-recommended   include recommended desktop packages`)
}
