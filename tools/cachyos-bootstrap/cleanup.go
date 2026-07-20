package main

import (
	"fmt"
	"os/exec"
	"strings"
)

type cleanupOptions struct {
	apply bool
}

var cleanupGroups = []struct {
	title    string
	packages []string
}{
	{
		title: "Replaced by Nix/Home Manager",
		packages: []string{
			"bat",
			"delta",
			"eza",
			"fastfetch",
			"fd",
			"fzf",
			"ghostty",
			"ghostty-shell-integration",
			"ghostty-terminfo",
			"git",
			"localsend",
			"mise",
			"maplemono-cn",
			"maplemono-nf-cn",
			"ripgrep",
			"starship",
			"zoxide",
			"adobe-source-han-sans-otc-fonts",
			"adobe-source-han-serif-otc-fonts",
			"bibata-cursor-theme",
			"noto-fonts-emoji",
			"noto-fonts-color-emoji",
			"papirus-icon-theme",
			"inter-font",
			"ttf-inter",
			"ttf-twemoji-color",
		},
	},
	{
		title:    "Retired Qt theme stack",
		packages: []string{"kvantum", "kvantum-qt5"},
	},
	{
		title: "Retired fish shell stack",
		packages: []string{
			"cachyos-fish-config",
			"fish",
			"fish-autopair",
			"fish-pure-prompt",
			"fisher",
		},
	},
	{
		title:    "Retired fcitx GUI tooling",
		packages: []string{"fcitx5-configtool"},
	},
}

func (a app) runCleanup(opts cleanupOptions) error {
	installedByGroup := make(map[string][]string)
	var installed []string
	for _, group := range cleanupGroups {
		for _, pkg := range group.packages {
			if pacmanPackageInstalled(pkg) {
				installedByGroup[group.title] = append(installedByGroup[group.title], pkg)
				installed = append(installed, pkg)
			}
		}
	}
	installed = uniqueSorted(installed)

	var safe []string
	var blocked []string
	for _, pkg := range installed {
		blockers := reverseDependentsOutsideSet(pkg, installed)
		if len(blockers) == 0 {
			safe = append(safe, pkg)
		} else {
			blocked = append(blocked, fmt.Sprintf("%s <- %s", pkg, strings.Join(blockers, " ")))
		}
	}

	if len(safe) == 0 && len(blocked) == 0 {
		fmt.Println(`No cleanup candidates from the migrated shell set are currently installed.

Still kept on purpose:
  zsh
Reason:
  Your login shell is still /usr/bin/zsh, so removing the system zsh package is unsafe.`)
		return nil
	}

	if opts.apply {
		if len(safe) == 0 {
			fmt.Println("No safe duplicate packages can be removed right now.")
			fmt.Println("Everything detected is still required by other pacman/AUR packages.")
			return nil
		}
		fmt.Println("Removing pacman packages that are now replaced by Nix or retired stacks...")
		fmt.Println("Keeping zsh installed because the login shell is still /usr/bin/zsh.")
		if err := requireSudo(); err != nil {
			return err
		}
		return run("sudo", append([]string{"pacman", "-Rns"}, safe...)...)
	}

	fmt.Println("Dry run only.")
	printList("Safe to remove now:", safe)
	printList("Blocked by reverse dependencies:", blocked)
	for _, group := range cleanupGroups {
		printList(group.title+":", installedByGroup[group.title])
	}
	fmt.Println(`
Not included on purpose:
  fcitx5 fcitx5-gtk fcitx5-qt fcitx5-rime librime librime-data zsh
Reason:
  Your login shell is still /usr/bin/zsh, so removing the system zsh package is unsafe.
  The system fcitx stack owns the runtime side; Nix manages config, theme, and Rime data around it.

To remove the duplicates, run:
  bootstrap/cachyos.sh cleanup --apply`)
	return nil
}

func reverseDependentsOutsideSet(pkg string, removalSet []string) []string {
	if !commandExists("pactree") {
		return nil
	}
	out, err := exec.Command("pactree", "-ru", pkg).Output()
	if err != nil {
		return nil
	}

	var dependents []string
	for _, line := range strings.Split(string(out), "\n") {
		dep := strings.TrimSpace(line)
		if dep == "" {
			continue
		}
		fields := strings.Fields(dep)
		dep = fields[len(fields)-1]
		dep = strings.Split(dep, "[")[0]
		dep = strings.TrimSuffix(dep, ":")
		if dep == "" || dep == pkg || stringInSlice(dep, removalSet) || stringInSlice(dep, dependents) {
			continue
		}
		dependents = append(dependents, dep)
	}
	return uniqueSorted(dependents)
}

func stringInSlice(needle string, items []string) bool {
	for _, item := range items {
		if item == needle {
			return true
		}
	}
	return false
}
