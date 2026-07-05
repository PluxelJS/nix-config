package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type app struct {
	repo string
	cfg  config
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

func sortedStringKeys[T any](m map[string]T) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func missingCommands(commands []string) []string {
	var missing []string
	for _, command := range commands {
		if !commandExists(command) {
			missing = append(missing, command)
		}
	}
	return missing
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
