package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

type guiConfigImport struct {
	title string
	from  string
	to    string
}

var guiConfigImports = []guiConfigImport{
	{title: "Mango appearance", from: ".config/mango/appearance.conf", to: "home/files/mango/appearance.conf"},
	{title: "Mango root config", from: ".config/mango/config.conf", to: "home/files/mango/config.conf"},
	{title: "Mango DMS bridge", from: ".config/mango/dms.conf", to: "home/files/mango/dms.conf"},
	{title: "Mango environment", from: ".config/mango/env.conf", to: "home/files/mango/env.conf"},
	{title: "Mango monitors", from: ".config/mango/monitors.conf", to: "home/files/mango/monitors.conf"},
	{title: "Mango rules entrypoint", from: ".config/mango/rules.conf", to: "home/files/mango/rules.conf"},
	{title: "Mango startup", from: ".config/mango/startup.conf", to: "home/files/mango/startup.conf"},
	{title: "Mango geometry rules", from: ".config/mango/rules/10-float-and-geometry.conf", to: "home/files/mango/rules/10-float-and-geometry.conf"},
	{title: "Mango tag rules", from: ".config/mango/rules/20-tags.conf", to: "home/files/mango/rules/20-tags.conf"},
	{title: "Mango game rules", from: ".config/mango/rules/90-games.conf", to: "home/files/mango/rules/90-games.conf"},
	{title: "Ghostty config", from: ".config/ghostty/config", to: "home/files/ghostty/config"},
	{title: "Dolphin config", from: ".config/dolphinrc", to: "home/files/dolphin/dolphinrc"},
	{title: "Dolphin UI", from: ".local/share/kxmlgui5/dolphin/dolphinui.rc", to: "home/files/dolphin/dolphinui.rc"},
	{title: "fcitx config", from: ".config/fcitx5/config", to: "home/files/fcitx5/config"},
	{title: "fcitx profile", from: ".config/fcitx5/profile", to: "home/files/fcitx5/profile"},
	{title: "fcitx classic UI", from: ".config/fcitx5/conf/classicui.conf", to: "home/files/fcitx5/conf/classicui.conf"},
	{title: "fcitx clipboard", from: ".config/fcitx5/conf/clipboard.conf", to: "home/files/fcitx5/conf/clipboard.conf"},
	{title: "fcitx input selector", from: ".config/fcitx5/conf/imselector.conf", to: "home/files/fcitx5/conf/imselector.conf"},
	{title: "fcitx notifications", from: ".config/fcitx5/conf/notifications.conf", to: "home/files/fcitx5/conf/notifications.conf"},
	{title: "fcitx quickphrase", from: ".config/fcitx5/conf/quickphrase.conf", to: "home/files/fcitx5/conf/quickphrase.conf"},
	{title: "fcitx Wayland", from: ".config/fcitx5/conf/wayland.conf", to: "home/files/fcitx5/conf/wayland.conf"},
	{title: "fcitx Wayland IM", from: ".config/fcitx5/conf/waylandim.conf", to: "home/files/fcitx5/conf/waylandim.conf"},
}

func (a app) runPullGUIConfig(opts pullGUIConfigOptions) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	fmt.Printf("GUI config import:\n  repo: %s\n  mode: %s\n\n", a.repo, modeName(opts.apply))
	fmt.Println("Only whitelisted, non-secret, static GUI config files are considered.")
	fmt.Println("Runtime state such as DMS colors, gh auth, KWallet, app caches, user dictionaries, and Flatpak private state is intentionally excluded.")

	var changed int
	var missing int
	for _, item := range guiConfigImports {
		source := filepath.Join(home, item.from)
		target := filepath.Join(a.repo, item.to)
		sourceData, err := os.ReadFile(source)
		if err != nil {
			if os.IsNotExist(err) {
				missing++
				warn("%s missing at %s", item.title, source)
				continue
			}
			return fmt.Errorf("read %s: %w", source, err)
		}

		targetData, err := os.ReadFile(target)
		targetExists := err == nil
		if err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("read %s: %w", target, err)
		}
		if targetExists && bytes.Equal(sourceData, targetData) {
			pass("%s unchanged", item.title)
			continue
		}

		changed++
		if !opts.apply {
			if targetExists {
				warn("%s differs; would import %s -> %s", item.title, source, target)
			} else {
				warn("%s has no repo target; would import %s -> %s", item.title, source, target)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return fmt.Errorf("create parent for %s: %w", target, err)
		}
		mode := os.FileMode(0o644)
		if info, err := os.Stat(source); err == nil {
			mode = info.Mode().Perm()
		}
		if err := os.WriteFile(target, sourceData, mode); err != nil {
			return fmt.Errorf("write %s: %w", target, err)
		}
		pass("%s imported", item.title)
	}

	fmt.Printf("\nSummary:\n  changed: %d\n  missing runtime files: %d\n", changed, missing)
	if !opts.apply && changed > 0 {
		fmt.Printf("\nApply imports:\n  %s\n", shellJoin([]string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "pull-gui-config", "--apply"}))
	}
	return nil
}
