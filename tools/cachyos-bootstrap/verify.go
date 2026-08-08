package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

type verifyOptions struct {
	profile string
	verbose bool
}

type verifier struct {
	home       string
	profile    string
	features   map[string]bool
	userGroups []string
	verbose    bool
	passes     int
	failures   int
}

func (a app) runVerify(opts verifyOptions) error {
	v, err := newVerifier(a.cfg, opts)
	if err != nil {
		return err
	}
	v.run()
	if v.failures > 0 {
		return fmt.Errorf("verification finished: %d passed, %d failed", v.passes, v.failures)
	}
	fmt.Printf("Verification checks passed: %d.\n", v.passes)
	return nil
}

func newVerifier(cfg config, opts verifyOptions) (*verifier, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	profile := opts.profile
	profilePath := filepath.Join(home, ".config", "ahdg", "profile")
	if profile == "" {
		if data, err := os.ReadFile(profilePath); err == nil {
			profile = strings.TrimSpace(string(data))
		}
	}
	if profile == "" {
		profile = "desktop"
	}

	featuresPath := filepath.Join(home, ".config", "ahdg", "enabled-features")
	features := map[string]bool{}
	if data, err := os.ReadFile(featuresPath); err == nil {
		features = linesAsSet(string(data))
	} else {
		profileCfg, ok := cfg.Profiles[profile]
		if !ok {
			return nil, fmt.Errorf("unsupported profile: %s", profile)
		}
		for _, feature := range profileCfg.Features {
			features[feature] = true
		}
	}

	return &verifier{
		home:       home,
		profile:    profile,
		features:   features,
		userGroups: cfg.UserGroups[profile],
		verbose:    opts.verbose,
	}, nil
}

func (v *verifier) run() {
	v.checkSymlink(".zshenv")
	v.checkSymlink(".config/zsh/.zshenv")
	v.checkSymlink(".config/zsh/.zshrc")
	v.checkSymlink(".config/starship/starship.toml")
	v.checkSymlink(".config/atuin/config.toml")
	v.checkFile(".config/ahdg/profile")

	if strings.TrimSpace(readFile(filepath.Join(v.home, ".config", "ahdg", "profile"))) == v.profile {
		v.pass("runtime profile marker matches %s", v.profile)
	} else {
		v.fail("runtime profile marker does not match %s", v.profile)
	}
	v.checkUserGroups()

	if v.has("ghostty") {
		v.checkSymlink(".config/ghostty/config")
		v.checkSymlink(".config/xdg-terminals.list")
	}
	if v.has("fastfetch") {
		v.checkSymlink(".config/fastfetch/config.jsonc")
	}
	if v.has("desktopXdg") {
		v.checkWritableRegularFile(".config/mimeapps.list")
		v.checkRegularPath(".local/share/applications/mimeapps.list", "%s is a materialized MIME policy fallback", "%s should be a regular MIME policy fallback")
		v.checkSymlink(".config/user-dirs.dirs")
		v.checkSymlink(".config/user-dirs.locale")
	}
	if v.has("gui") {
		v.checkGUIFiles()
		v.checkMutableKDEConfig()
	}
	if v.has("portal") {
		v.checkSymlink(".config/xdg-desktop-portal/portals.conf")
	}
	if v.has("flatpak") {
		v.checkSymlink(".local/share/flatpak/overrides/global")
	}
	if v.has("fonts") {
		v.checkFonts()
	}

	v.checkWritableRegularFile(".gitconfig")

	if v.has("fonts") {
		v.checkRegularPath(".config/fontconfig/fonts.conf", "%s is materialized for Flatpak", "%s should be a regular file for Flatpak compatibility")
		if !hasSymlinkGlob(filepath.Join(v.home, ".config", "fontconfig", "conf.d"), "*-hm-*.conf") {
			v.pass("%s snippets are materialized for Flatpak", filepath.Join(v.home, ".config", "fontconfig", "conf.d"))
		} else {
			v.fail("%s snippets should not be store symlinks for Flatpak compatibility", filepath.Join(v.home, ".config", "fontconfig", "conf.d"))
		}
	}

	if v.has("gui") {
		v.checkMaterializedGUI()
	}
	if v.has("localsend") {
		v.checkLocalSend()
	}

	if v.has("themeRuntime") {
		p := v.path(".config/ghostty/config-dankcolors")
		if isRegular(p) && !isSymlink(p) && isWritable(p) {
			v.pass("%s is writable for DMS", p)
		} else {
			v.fail("%s must be a writable regular file", p)
		}
	}

	if v.has("fastfetch") {
		v.checkFile(".config/fastfetch/assets/1544x1544_circle.png")
	}

	v.checkInteractiveShell()
	v.checkFlatpakApps()
	v.checkDesktopRuntime()
}

func (v *verifier) checkLocalSend() {
	if commandExists("localsend_app") && commandExists("localsend") {
		v.pass("LocalSend is installed through the Home Manager profile")
	} else {
		v.fail("Nix-managed LocalSend launchers are missing")
	}

	profile := readFile(localSendUFWProfilePath)
	if strings.Contains(profile, "[LocalSend]") && strings.Contains(profile, "ports=53317/tcp|53317/udp") {
		v.pass("LocalSend UFW application profile declares TCP/UDP 53317")
	} else {
		v.fail("LocalSend UFW application profile is missing or invalid")
	}
	if localSendUFWRulesPresent() {
		v.pass("LocalSend UFW rules allow discovery and transfer on TCP/UDP 53317")
	} else {
		v.fail("LocalSend UFW rules are missing TCP/UDP 53317")
	}
}

func (v *verifier) checkGUIFiles() {
	for _, rel := range []string{
		".gtkrc-2.0",
		".config/fcitx5/config",
		".config/fcitx5/profile",
		".config/fcitx5/conf/classicui.conf",
		".local/share/fcitx5/themes/plasma/theme.conf",
		".local/share/fcitx5/themes/catppuccin-macchiato-lavender/theme.conf",
		".local/share/fcitx5/themes/catppuccin-mocha-lavender/theme.conf",
		".local/share/fcitx5/rime/default.yaml",
		".local/share/fcitx5/rime/wanxiang.schema.yaml",
		".local/share/fcitx5/rime/wanxiang-lts-zh-hans.gram",
		".config/gtk-3.0/settings.ini",
		".config/gtk-4.0/gtk.css",
		".config/xsettingsd/xsettingsd.conf",
		".config/ahdg/theme/session.env",
		".config/ahdg/theme/mode",
		".local/share/themes/Catppuccin-Macchiato/index.theme",
		".local/share/themes/Catppuccin-Latte/index.theme",
		".local/share/icons/Papirus/index.theme",
		".local/share/icons/breeze/index.theme",
		".local/share/icons/Bibata-Modern-Ice/index.theme",
		".config/color-schemes/CatppuccinMacchiatoLavender.colors",
		".local/share/color-schemes/CatppuccinMacchiatoLavender.colors",
		".config/color-schemes/CatppuccinLatteLavender.colors",
		".local/share/color-schemes/CatppuccinLatteLavender.colors",
	} {
		v.checkFile(rel)
	}
	for _, rel := range []string{
		".config/systemd/user/mango-session.target",
		".config/menus/plasma-applications.menu",
		".local/share/plasma/look-and-feel/Catppuccin-Macchiato-Lavender",
		".local/share/plasma/look-and-feel/Catppuccin-Latte-Lavender",
		".local/share/aurorae/themes/CatppuccinMacchiato-Modern",
		".local/share/aurorae/themes/CatppuccinLatte-Modern",
	} {
		v.checkSymlink(rel)
	}
}

func (v *verifier) checkMutableKDEConfig() {
	for _, rel := range []string{
		".config/arkrc",
		".config/dolphinrc",
		".config/kcminputrc",
		".config/kdeglobals",
		".local/share/kxmlgui5/dolphin/dolphinui.rc",
	} {
		v.checkWritableRegularFile(rel)
	}
}

func (v *verifier) checkFonts() {
	for _, rel := range []string{
		".config/fontconfig/fonts.conf",
		".config/fontconfig/conf.d/53-hm-ahdg-ui-font-mappings.conf",
		".local/share/fonts/custom/README.txt",
	} {
		v.checkFile(rel)
	}
}

func (v *verifier) checkMaterializedGUI() {
	for _, rel := range []string{
		".gtkrc-2.0",
		".config/fcitx5/config",
		".config/fcitx5/profile",
		".config/fcitx5/conf/classicui.conf",
		".local/share/fcitx5/themes/plasma",
		".local/share/fcitx5/themes/catppuccin-macchiato-lavender",
		".local/share/fcitx5/themes/catppuccin-mocha-lavender",
		".config/gtk-3.0/settings.ini",
		".config/xsettingsd/xsettingsd.conf",
		".config/gtk-4.0",
		".local/share/themes/Catppuccin-Macchiato",
		".local/share/themes/Catppuccin-Latte",
		".local/share/icons/Papirus",
		".local/share/icons/breeze",
		".local/share/icons/Bibata-Modern-Ice",
		".config/color-schemes/CatppuccinMacchiatoLavender.colors",
		".local/share/color-schemes/CatppuccinMacchiatoLavender.colors",
		".config/color-schemes/CatppuccinLatteLavender.colors",
		".local/share/color-schemes/CatppuccinLatteLavender.colors",
	} {
		v.checkRegularPath(rel, "%s is materialized for Flatpak", "%s should be a regular file or directory for Flatpak compatibility")
	}

	v.checkFlatpakOverridesWritable()
}

func (v *verifier) checkFlatpakOverridesWritable() {
	overridesDir := v.path(".local/share/flatpak/overrides")
	if !isDir(overridesDir) {
		v.fail("%s is missing", overridesDir)
		return
	}
	entries, err := os.ReadDir(overridesDir)
	if err != nil {
		v.fail("cannot read %s", overridesDir)
		return
	}
	issue := false
	for _, entry := range entries {
		p := filepath.Join(overridesDir, entry.Name())
		if p == v.path(".local/share/flatpak/overrides/global") {
			continue
		}
		if entry.Type().IsRegular() && isSymlink(p) {
			v.fail("%s should remain app-managed, not Nix-managed", p)
			issue = true
		}
	}
	if !issue {
		v.pass("Flatpak app-specific overrides remain activation-managed and writable")
	}
}

func (v *verifier) checkUserGroups() {
	user := os.Getenv("USER")
	for _, group := range v.userGroups {
		if !groupExists(group) {
			v.fail("required user group `%s` is missing", group)
			continue
		}
		if userInGroup(user, group) {
			v.pass("%s is in required user group `%s`", user, group)
		} else {
			v.fail("%s is not in required user group `%s`", user, group)
		}
	}
}

func (v *verifier) checkInteractiveShell() {
	expectedTools := []string{"zsh", "starship", "git", "gh", "fzf", "zoxide", "mise", "atuin"}
	if v.has("fastfetch") {
		expectedTools = append(expectedTools, "fastfetch")
	}
	if v.has("ghostty") {
		expectedTools = append(expectedTools, "ghostty")
	}
	if v.has("gui") {
		expectedTools = append(expectedTools, "copyq", "file", "mark-shot", "notify-send", "openrazer-daemon", "polychromatic-controller", "songrec", "wl-paste")
	}
	if commandOK("zsh", "-i", "-c", "command -v "+strings.Join(expectedTools, " ")+" >/dev/null") {
		v.pass("interactive zsh resolves the managed toolchain")
	} else {
		v.fail("interactive zsh cannot resolve one or more managed tools")
	}

	if v.has("ghostty") {
		v.checkZsh("[[ \"$ELECTRON_OZONE_PLATFORM_HINT\" == \"auto\" && \"$TERMINAL\" == \"ghostty\" ]]", "interactive zsh exports the desktop helper environment", "interactive zsh is missing desktop helper environment variables")
	}
	if v.has("desktopXdg") {
		v.checkZsh("[[ \"$XDG_DESKTOP_DIR\" == \"$HOME/桌面\" && \"$XDG_DOWNLOAD_DIR\" == \"$HOME/下载\" ]]", "interactive zsh exports the managed XDG user directories", "interactive zsh is missing managed XDG user directory variables")
	}
	if v.has("gui") {
		v.checkZsh("command -v darkly-settings6 >/dev/null", "Darkly is provided by the system KDE/Qt package set", "Darkly is missing from the system KDE/Qt package set")
		v.checkZsh("[[ \"$INPUT_METHOD\" == \"fcitx\" && \"$XMODIFIERS\" == \"@im=fcitx\" && \"$GTK_IM_MODULE\" == \"fcitx\" && \"$QT_IM_MODULE\" == \"fcitx\" && \"$QT_IM_MODULES\" == \"wayland;fcitx\" ]]", "interactive zsh exports the managed fcitx environment", "interactive zsh is missing part of the managed fcitx environment")
	}
	if v.has("fonts") {
		if regexp.MustCompile(`^Inter`).MatchString(commandOutput("fc-match", "sans-serif")) {
			v.pass("sans-serif resolves to the Nix-managed Inter stack")
		} else {
			v.fail("sans-serif no longer resolves to Inter")
		}
		if regexp.MustCompile(`^(MapleMono-NF-CN|MapleMono-NF-CN-|Maple Mono NF CN)`).MatchString(commandOutput("fc-match", "monospace")) {
			v.pass("monospace resolves to the Nix-managed Maple Mono stack")
		} else {
			v.fail("monospace no longer resolves to Maple Mono NF CN")
		}
		if regexp.MustCompile(`^SourceHanSerif.*"Source Han Serif SC"`).MatchString(commandOutput("fc-match", "serif")) {
			v.pass("serif resolves to the Nix-managed Source Han Serif stack")
		} else {
			v.fail("serif no longer resolves to Source Han Serif SC")
		}
		if regexp.MustCompile(`^NotoColorEmoji.*"Noto Color Emoji"`).MatchString(commandOutput("fc-match", "emoji")) {
			v.pass("emoji resolves to Noto Color Emoji")
		} else {
			v.fail("emoji no longer resolves to Noto Color Emoji")
		}
	}

	v.checkZsh("bindkey '^R' | grep -q 'atuin-search'", "Atuin owns the interactive history keybinding", "Ctrl-R is not bound to Atuin history search")
	v.checkZsh("command -v pay-respects >/dev/null && alias f >/dev/null", "pay-respects is installed and wired into zsh", "pay-respects is missing or its zsh alias is unavailable")
	v.checkCleanZshWithoutTerm()
}

func (v *verifier) checkFlatpakApps() {
	if !v.has("flatpak") {
		return
	}
	v.checkCodeStudio()
	v.checkCLion()
	if !flatpakAppInstalled("org.telegram.desktop") {
		return
	}

	if commandOK("flatpak", "run", "--command=sh", "org.telegram.desktop", "-c", "fc-match sans-serif 2>/dev/null | grep -q '^Inter'") {
		v.pass("Telegram Flatpak now picks up the user fontconfig stack")
	} else {
		v.fail("Telegram Flatpak is still missing the user fontconfig stack")
	}
	if commandOK("flatpak", "run", "--command=sh", "org.telegram.desktop", "-c", "test -f ~/.config/gtk-3.0/settings.ini && test -f ~/.local/share/themes/Catppuccin-Macchiato/index.theme && test -f ~/.local/share/themes/Catppuccin-Latte/index.theme && test -f ~/.local/share/icons/Papirus/index.theme && test -f ~/.local/share/icons/breeze/index.theme && test -f ~/.config/color-schemes/CatppuccinMacchiatoLavender.colors && test -f ~/.config/color-schemes/CatppuccinLatteLavender.colors") {
		v.pass("Telegram Flatpak can read the materialized theme stack")
	} else {
		v.fail("Telegram Flatpak is still missing part of the materialized theme stack")
	}
	if commandOK("flatpak", "run", "--command=sh", "org.telegram.desktop", "-c", "test -f ~/.config/fcitx5/config && test -f ~/.local/share/fcitx5/themes/plasma/theme.conf && test -f ~/.local/share/fcitx5/rime/default.yaml && printenv XMODIFIERS | grep -qx '@im=fcitx' && printenv QT_IM_MODULES | grep -qx 'wayland;fcitx'") {
		v.pass("Telegram Flatpak can read the managed fcitx and rime stack")
	} else {
		v.fail("Telegram Flatpak is still missing part of the fcitx or rime stack")
	}

	globalOverride := v.path(".local/share/flatpak/overrides/global")
	if fileLineMatches(globalOverride, `^filesystems=.*xdg-config/kdeglobals:ro.*xdg-data/themes:ro`) &&
		!fileContainsRegex(globalOverride, `/usr/share/icons|/usr/share/themes|xdg-config/qt5ct|xdg-config/qt6ct`) {
		v.pass("Flatpak global override matches the Nix-managed host integration policy")
	} else {
		v.fail("Flatpak global override does not match the expected Nix-managed policy")
	}
}

func (v *verifier) checkCodeStudio() {
	appID := "io.github.trumank.CodeStudio"
	if !flatpakAppInstalled(appID) {
		return
	}
	home := shellQuote(v.home)
	if flatpakShell(appID, "for cmd in zsh mise git gh opencode node npm npx; do command -v \"$cmd\" >/dev/null 2>&1 || exit 1; done") {
		v.pass("Code Studio terminal resolves the shared host-managed toolchain")
	} else {
		v.fail("Code Studio terminal is missing part of the shared host-managed toolchain")
	}
	if flatpakShell(appID, fmt.Sprintf("test -f %s/.config/zsh/.zshrc && test -f %s/.config/starship/starship.toml && test -f %s/.config/atuin/config.toml && test -f %s/.config/opencode/tui.json", home, home, home, home)) {
		v.pass("Code Studio can read the host-side shared shell and opencode config")
	} else {
		v.fail("Code Studio cannot read the shared shell or opencode config")
	}
	if flatpakShell(appID, fmt.Sprintf("test \"$CODEX_HOME\" = %s/.local/share/codex && test -f \"$CODEX_HOME/config.toml\" && test \"$(readlink -f \"$CODEX_HOME/config.toml\")\" = %s/.codex/config.toml", home, home)) {
		v.pass("Code Studio uses app-private CODEX_HOME state with the host Codex config")
	} else {
		v.fail("Code Studio is not wired to the host Codex config as expected")
	}
	if !fileContainsRegex(commandOutput("flatpak", "override", "--user", "--show", appID), `(?m)^persistent=(.*;)?\.codex(;|$)`) {
		v.pass("Code Studio does not persist the obsolete ~/.codex mount")
	} else {
		v.fail("Code Studio should keep Codex state under app-private CODEX_HOME instead of persistent ~/.codex")
	}
	if flatpakShell(appID, fmt.Sprintf("! grep -q \" %s/.codex/config.toml %s/.codex/config.toml \" /proc/self/mountinfo", v.home, v.home)) {
		v.pass("Code Studio exposes Codex config through a directory mount for atomic writes")
	} else {
		v.fail("Code Studio should not expose Codex config as a single-file mount")
	}
	if flatpakShell(appID, secretPolicyScript()) {
		v.pass("Code Studio can reach the host secret service and KWallet session bus names")
	} else {
		v.fail("Code Studio is missing the host secret service or KWallet session bus policy")
	}
}

func (v *verifier) checkCLion() {
	appID := "com.jetbrains.CLion"
	if !flatpakAppInstalled(appID) {
		return
	}
	home := shellQuote(v.home)
	profileZsh := filepath.Join(v.home, ".local", "state", "nix", "profiles", "profile", "bin", "zsh")
	if flatpakShell(appID, "for cmd in zsh git gh opencode node npm npx; do command -v \"$cmd\" >/dev/null 2>&1 || exit 1; done") {
		v.pass("CLion terminal resolves the shared host-managed toolchain")
	} else {
		v.fail("CLion terminal is missing part of the shared host-managed toolchain")
	}
	if flatpakShell(appID, fmt.Sprintf("test -f %s/.config/zsh/.zshrc && test -f %s/.config/starship/starship.toml && test -f %s/.config/atuin/config.toml && test -f %s/.config/opencode/tui.json", home, home, home, home)) {
		v.pass("CLion can read the host-side shared shell and opencode config")
	} else {
		v.fail("CLion cannot read the shared shell or opencode config")
	}
	if flatpakShell(appID, fmt.Sprintf("test \"$CODEX_HOME\" = %s/.local/share/codex && test -f \"$CODEX_HOME/config.toml\" && test \"$(readlink -f \"$CODEX_HOME/config.toml\")\" = %s/.codex/config.toml", home, home)) {
		v.pass("CLion uses app-private CODEX_HOME state with the host Codex config")
	} else {
		v.fail("CLion is not wired to the host Codex config as expected")
	}
	if !fileContainsRegex(commandOutput("flatpak", "override", "--user", "--show", appID), `(?m)^persistent=(.*;)?\.codex(;|$)`) {
		v.pass("CLion does not persist the obsolete ~/.codex mount")
	} else {
		v.fail("CLion should keep Codex state under app-private CODEX_HOME instead of persistent ~/.codex")
	}
	if flatpakShell(appID, fmt.Sprintf("! grep -q \" %s/.codex/config.toml %s/.codex/config.toml \" /proc/self/mountinfo", v.home, v.home)) {
		v.pass("CLion exposes Codex config through a directory mount for atomic writes")
	} else {
		v.fail("CLion should not expose Codex config as a single-file mount")
	}
	if flatpakShell(appID, "test -d \"$XDG_CONFIG_HOME/JetBrains\" && test -d \"$XDG_DATA_HOME/JetBrains\" && test -d \"$XDG_CACHE_HOME/JetBrains\"") {
		v.pass("CLion keeps JetBrains config, data, and cache in app-private XDG state")
	} else {
		v.fail("CLion is missing one of the app-private JetBrains XDG state directories")
	}
	if isDir(filepath.Join(v.home, ".var/app/com.jetbrains.CLion/home/.config/JetBrains")) &&
		isDir(filepath.Join(v.home, ".var/app/com.jetbrains.CLion/home/.local/share/JetBrains")) &&
		isDir(filepath.Join(v.home, ".var/app/com.jetbrains.CLion/home/.cache/JetBrains")) &&
		evalSymlink(filepath.Join(v.home, ".var/app/com.jetbrains.CLion/home/.codex/config.toml")) == filepath.Join(v.home, ".codex/config.toml") {
		v.pass("CLion exposes a host-side home view for app-private XDG and Codex state")
	} else {
		v.fail("CLion host-side home view is missing an expected compatibility path")
	}
	if flatpakShell(appID, "sed -n '/\\[Context\\]/,/\\[Session Bus Policy\\]/p' /.flatpak-info | grep -q '^sockets=wayland;$'") {
		v.pass("CLion stays on Wayland-only sockets without X11 fallback")
	} else {
		v.fail("CLion should stay on Wayland-only sockets without X11 fallback")
	}
	if flatpakShell(appID, secretPolicyScript()) {
		v.pass("CLion can reach the host secret service and KWallet session bus names")
	} else {
		v.fail("CLion is missing the host secret service or KWallet session bus policy")
	}
	if flatpakShell(appID, "env_block=\"$(sed -n '/\\[Environment\\]/,/^\\[/p' /.flatpak-info)\"; printf '%s\n' \"$env_block\" | grep -q '^FLATPAK_IDE_ENV=1$' && printf '%s\n' \"$env_block\" | grep -Fqx "+shellQuote("SHELL="+profileZsh)+" && printf '%s\n' \"$env_block\" | grep -q '^GTK_IM_MODULE=$' && printf '%s\n' \"$env_block\" | grep -q '^QT_IM_MODULE=$' && printf '%s\n' \"$env_block\" | grep -q '^QT_IM_MODULES=wayland$' && printf '%s\n' \"$env_block\" | grep -q '^XMODIFIERS=$'") {
		v.pass("CLion keeps its Wayland-specific input env override instead of inheriting desktop IM settings")
	} else {
		v.fail("CLion should keep its Wayland-specific input env override")
	}
	if flatpakShell(appID, "options_dir=\"$(find \"$XDG_CONFIG_HOME/JetBrains\" -maxdepth 2 -mindepth 2 -type d -name options | sort | head -n1)\"; test -n \"$options_dir\" && grep -q 'FONT_FAMILY\" value=\"Maple Mono NF CN\"' \"$options_dir/editor-font.xml\" && grep -q 'FONT_FAMILY\" value=\"Maple Mono NF CN\"' \"$options_dir/terminal-font.xml\" && (grep -Fq "+shellQuote("myShellPath\" value=\""+profileZsh)+" \"$options_dir/terminal.xml\" || grep -Fq 'myShellPath\" value=\"$USER_HOME$/.local/state/nix/profiles/profile/bin/zsh' \"$options_dir/terminal.xml\") && grep -q 'terminalEngine\" value=\"CLASSIC\"' \"$options_dir/terminal.xml\" && grep -q 'terminalEngineInRemDev\" value=\"CLASSIC\"' \"$options_dir/terminal.xml\" && grep -q 'selectedLocale\" value=\"zh-CN\"' \"$options_dir/ide.general.xml\"") {
		v.pass("CLion has JetBrains-wide seeded defaults for font, classic terminal shell, and locale")
	} else {
		v.fail("CLion is missing one of the JetBrains-wide seeded IDE defaults")
	}
	if flatpakShell(appID, "test -f \"$HOME/.java/.userPrefs/jetbrains/region/prefs.xml\" && grep -q 'key=\"code\" value=\"apac\"' \"$HOME/.java/.userPrefs/jetbrains/region/prefs.xml\"") {
		v.pass("CLion persists JetBrains Java Preferences with a fixed region code")
	} else {
		v.fail("CLion is missing the persisted JetBrains Java Preferences region code")
	}
}

func (v *verifier) checkDesktopRuntime() {
	if v.has("desktopXdg") {
		if strings.TrimSpace(commandOutput("xdg-mime", "query", "default", "text/plain")) == "NotepadNext.desktop" {
			v.pass("Notepad Next is the effective text/plain default")
		} else {
			v.fail("Notepad Next is not the effective text/plain default")
		}
	}

	if v.has("gui") {
		userEnvironment := commandOutput("systemctl", "--user", "show-environment")
		if regexp.MustCompile(`(?m)^XDG_MENU_PREFIX=plasma-$`).MatchString(userEnvironment) &&
			regexp.MustCompile(`(?m)^XDG_CONFIG_DIRS=/nix/store/.*/etc/xdg:/etc/xdg$`).MatchString(userEnvironment) {
			v.pass("systemd user environment selects the Nix Plasma application menu")
		} else {
			v.fail("systemd user environment does not select the Nix Plasma application menu")
		}
		dolphinUnit := commandOutput("systemctl", "--user", "cat", "plasma-dolphin.service")
		if dolphinUnit != "" && strings.Contains(dolphinUnit, ".config/ahdg/theme/session.env") && strings.Contains(dolphinUnit, "/nix/store/") {
			v.pass("Dolphin FileManager1 daemon uses the Nix KDE runtime and dynamic environment")
		} else {
			v.fail("Dolphin FileManager1 daemon is not fully Nix-owned")
		}
		dolphinLauncher, dolphinErr := exec.LookPath("dolphin")
		dolphinLauncherText := readFile(dolphinLauncher)
		pluginPathMatch := regexp.MustCompile(`(?m)^export QT_PLUGIN_PATH=([^:\n]+)`).FindStringSubmatch(dolphinLauncherText)
		if dolphinErr == nil && len(pluginPathMatch) == 2 &&
			strings.Contains(dolphinLauncherText, "export QT_QPA_PLATFORMTHEME=kde") &&
			strings.Contains(dolphinLauncherText, "export QT_QPA_PLATFORMTHEME_QT6=kde") &&
			isRegular(filepath.Join(pluginPathMatch[1], "platformthemes", "KDEPlasmaPlatformTheme6.so")) &&
			isRegular(filepath.Join(pluginPathMatch[1], "styles", "darkly6.so")) &&
			isRegular(filepath.Join(pluginPathMatch[1], "styles", "breeze6.so")) {
			v.pass("Dolphin can load the Nix KDE platform theme and Darkly/Breeze styles")
		} else {
			v.fail("Dolphin is missing the Nix KDE platform theme or Darkly/Breeze styles")
		}
		kdedUnit := commandOutput("systemctl", "--user", "cat", "plasma-kded6.service")
		if kdedUnit != "" && strings.Contains(kdedUnit, "XDG_MENU_PREFIX=plasma-") && strings.Contains(kdedUnit, "/nix/store/") &&
			regexp.MustCompile(`(?m)^Exe=/nix/store/.*/bin/(\.kded6-wrapped|kded6)$`).MatchString(commandOutput("busctl", "--user", "status", "org.kde.kded6")) {
			v.pass("KDED uses the Nix KDE runtime and Plasma application menu")
		} else {
			v.fail("KDED is not fully Nix-owned")
		}
		polkitUnit := commandOutput("systemctl", "--user", "cat", "plasma-polkit-agent.service")
		if polkitUnit != "" && strings.Contains(polkitUnit, "/nix/store/") {
			v.pass("KDE PolicyKit agent uses the Nix runtime")
		} else {
			v.fail("KDE PolicyKit agent is not Nix-owned")
		}
		if regexp.MustCompile(`(?m)^Exe=/usr/bin/fcitx5$`).MatchString(commandOutput("busctl", "--user", "status", "org.fcitx.Fcitx5")) {
			v.pass("fcitx runtime ownership is back on the system fcitx5 binary")
		} else {
			v.fail("fcitx runtime is not currently owned by the system fcitx5 binary")
		}
		if commandOK("mango", "-p", "-c", v.path(".config/mango/config.conf")) {
			v.pass("Mango config validates against the installed compositor")
		} else {
			v.fail("Mango config does not validate against the installed compositor")
		}
	}

	if v.has("ghostty") {
		if strings.TrimSpace(firstLine(v.path(".config/xdg-terminals.list"))) == "com.mitchellh.ghostty.desktop" {
			v.pass("Ghostty is the first XDG terminal preference")
		} else {
			v.fail("Ghostty is not the primary XDG terminal preference")
		}
		if commandOK("infocmp", "-x", "ghostty") {
			v.pass("ghostty terminfo is available")
		} else {
			v.fail("ghostty terminfo is missing")
		}
		v.checkGhosttySmoke()
	}

	if v.has("graphics") {
		if commandExists("nixGLMesa") {
			v.pass("nixGLMesa wrapper is installed")
		} else {
			v.fail("nixGLMesa wrapper is missing")
		}
	}

	if v.has("portal") {
		if regexp.MustCompile(`(?m)^NIX_XDG_DESKTOP_PORTAL_DIR=`).MatchString(commandOutput("systemctl", "--user", "show-environment")) {
			v.pass("systemd user environment exports the portal directory")
		} else {
			v.fail("systemd user environment is missing NIX_XDG_DESKTOP_PORTAL_DIR")
		}
		kdePortalUnit := commandOutput("systemctl", "--user", "cat", "plasma-xdg-desktop-portal-kde.service")
		kwalletUnit := commandOutput("systemctl", "--user", "cat", "kwalletd6.service")
		if kdePortalUnit != "" && strings.Contains(kdePortalUnit, ".config/ahdg/theme/session.env") && strings.Contains(kdePortalUnit, "/nix/store/") {
			v.pass("KDE portal backend uses the nixGL-bridged Nix runtime")
		} else {
			v.fail("KDE portal backend is not fully Nix-owned")
		}
		for _, unit := range []string{
			"xdg-desktop-portal.service",
			"xdg-document-portal.service",
			"xdg-permission-store.service",
			"xdg-desktop-portal-gtk.service",
			"xdg-desktop-portal-wlr.service",
		} {
			unitText := commandOutput("systemctl", "--user", "cat", unit)
			if unitText != "" && strings.Contains(unitText, "/nix/store/") {
				v.pass("%s uses the Nix runtime", unit)
			} else {
				v.fail("%s is not Nix-owned", unit)
			}
		}
		if fileLineMatches(v.path(".config/xdg-desktop-portal/portals.conf"), `^org\.freedesktop\.impl\.portal\.Settings=darkman;gtk;kde;\*$`) {
			v.pass("portal Settings prefers darkman for system color-scheme")
		} else if fileLineMatches(v.path(".config/xdg-desktop-portal/portals.conf"), `^org\.freedesktop\.impl\.portal\.Settings=gtk;kde;\*$`) {
			v.pass("portal Settings falls back to GTK/KDE when darkman auto-switching is disabled")
		} else {
			v.fail("portal Settings backend order is unexpected")
		}
		if fileLineMatches(v.path(".config/xdg-desktop-portal/portals.conf"), `^org\.freedesktop\.impl\.portal\.Secret=kwallet;\*$`) {
			v.pass("portal Secret prefers KWallet")
		} else {
			v.fail("portal Secret does not prefer KWallet")
		}
		if kwalletUnit != "" && strings.Contains(kwalletUnit, "ExecStart=") && strings.Contains(kwalletUnit, "kwalletd6") && strings.Contains(kwalletUnit, "/nix/store/") {
			v.pass("kwalletd6 user unit uses the Nix runtime")
		} else {
			v.fail("kwalletd6 user unit is not Nix-owned")
		}
		if regexp.MustCompile(`interface org\.freedesktop\.portal\.Secret`).MatchString(commandOutput("gdbus", "introspect", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop")) {
			v.pass("xdg-desktop-portal exposes the Secret interface")
		} else {
			v.fail("xdg-desktop-portal is missing the Secret interface")
		}
	}
}

func (v *verifier) checkZsh(script, okMessage, failMessage string) {
	if commandOK("zsh", "-i", "-c", script) {
		v.pass(okMessage)
	} else {
		v.fail(failMessage)
	}
}

func (v *verifier) checkCleanZshWithoutTerm() {
	logPath := filepath.Join(os.TempDir(), "verify-deployment.zsh.log")
	cmd := exec.Command("zsh", "-i", "-c", ":")
	cmd.Env = append(os.Environ(), "TERM=")
	out, err := cmd.CombinedOutput()
	_ = os.WriteFile(logPath, out, 0o644)
	if err == nil && len(out) == 0 {
		v.pass("interactive zsh starts cleanly without TERM")
	} else if err == nil {
		v.fail("interactive zsh produced output without TERM; inspect %s", logPath)
	} else {
		v.fail("interactive zsh exited non-zero without TERM; inspect %s", logPath)
	}
}

func (v *verifier) checkGhosttySmoke() {
	stdoutPath := filepath.Join(os.TempDir(), "verify-deployment.ghostty.stdout")
	stderrPath := filepath.Join(os.TempDir(), "verify-deployment.ghostty.stderr")
	stdoutFile, stdoutErr := os.Create(stdoutPath)
	stderrFile, stderrErr := os.Create(stderrPath)
	if stdoutErr != nil || stderrErr != nil {
		v.fail("cannot create ghostty smoke test logs")
		return
	}
	defer stdoutFile.Close()
	defer stderrFile.Close()

	cmd := exec.Command("timeout", "5s", "ghostty")
	cmd.Stdout = stdoutFile
	cmd.Stderr = stderrFile
	err := cmd.Run()
	_ = stdoutFile.Close()
	_ = stderrFile.Close()
	if err == nil {
		v.pass("ghostty exited cleanly during smoke test")
	} else if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() != 124 {
		v.fail("ghostty smoke test exited non-zero; inspect %s", stderrPath)
	}

	stderr := readFile(stderrPath)
	if !regexp.MustCompile(`failed to make GL context current|创建 EGL 显示失败`).MatchString(stderr) {
		v.pass("ghostty no longer shows EGL/OpenGL initialization failures")
	} else {
		v.fail("ghostty still shows GL/EGL initialization errors; inspect %s", stderrPath)
	}
}

func (v *verifier) checkSymlink(rel string) {
	p := v.path(rel)
	if isSymlink(p) {
		v.pass("%s is managed by Home Manager", p)
	} else {
		v.fail("%s is not a Home Manager symlink", p)
	}
}

func (v *verifier) checkFile(rel string) {
	p := v.path(rel)
	if isRegular(p) {
		v.pass("%s exists", p)
	} else {
		v.fail("%s is missing", p)
	}
}

func (v *verifier) checkRegularPath(rel, okFormat, failFormat string) {
	p := v.path(rel)
	if pathExists(p) && !isSymlink(p) {
		v.pass(okFormat, p)
	} else {
		v.fail(failFormat, p)
	}
}

func (v *verifier) checkWritableRegularFile(rel string) {
	p := v.path(rel)
	if isRegular(p) && !isSymlink(p) && isWritable(p) {
		v.pass("%s is a writable regular file", p)
	} else {
		v.fail("%s must be a writable regular file", p)
	}
}

func (v *verifier) has(feature string) bool {
	return v.features[feature]
}

func (v *verifier) path(rel string) string {
	return filepath.Join(v.home, rel)
}

func (v *verifier) pass(format string, args ...any) {
	v.passes++
	if v.verbose {
		fmt.Printf("[ok] "+format+"\n", args...)
	}
}

func (v *verifier) fail(format string, args ...any) {
	fmt.Printf("[fail] "+format+"\n", args...)
	v.failures++
}

func flatpakShell(appID, script string) bool {
	return commandOK("flatpak", "run", "--command=sh", appID, "-c", script)
}

func secretPolicyScript() string {
	return "policy_block=\"$(sed -n '/\\[Session Bus Policy\\]/,/^\\[/p' /.flatpak-info)\"; printf '%s\n' \"$policy_block\" | grep -q '^org.freedesktop.secrets=talk$' && printf '%s\n' \"$policy_block\" | grep -q '^org.kde.kwalletd6=talk$' && printf '%s\n' \"$policy_block\" | grep -q '^org.kde.secretservicecompat=talk$'"
}

func commandOutput(name string, args ...string) string {
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		return ""
	}
	return string(out)
}

func pathExists(path string) bool {
	_, err := os.Lstat(path)
	return err == nil
}

func isSymlink(path string) bool {
	info, err := os.Lstat(path)
	return err == nil && info.Mode()&os.ModeSymlink != 0
}

func isRegular(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func isWritable(path string) bool {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		return false
	}
	_ = f.Close()
	return true
}

func hasSymlinkGlob(dir, pattern string) bool {
	matches, err := filepath.Glob(filepath.Join(dir, pattern))
	if err != nil {
		return false
	}
	for _, match := range matches {
		if isSymlink(match) {
			return true
		}
	}
	return false
}

func evalSymlink(path string) string {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return ""
	}
	return resolved
}

func readFile(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(data)
}

func firstLine(path string) string {
	text := readFile(path)
	line, _, _ := strings.Cut(text, "\n")
	return strings.TrimSpace(line)
}

func fileLineMatches(path, pattern string) bool {
	re, err := regexp.Compile(pattern)
	if err != nil {
		return false
	}
	for _, line := range strings.Split(readFile(path), "\n") {
		if re.MatchString(strings.TrimSpace(line)) {
			return true
		}
	}
	return false
}

func fileContainsRegex(textOrPath, pattern string) bool {
	text := textOrPath
	if pathExists(textOrPath) {
		text = readFile(textOrPath)
	}
	re, err := regexp.Compile(pattern)
	return err == nil && re.MatchString(text)
}

func kdeViewBackground(path string) string {
	inView := false
	for _, line := range strings.Split(readFile(path), "\n") {
		line = strings.TrimSpace(line)
		if line == "[Colors:View]" {
			inView = true
			continue
		}
		if strings.HasPrefix(line, "[") {
			inView = false
		}
		if inView {
			key, value, ok := strings.Cut(line, "=")
			if ok && key == "BackgroundNormal" {
				return value
			}
		}
	}
	return ""
}
