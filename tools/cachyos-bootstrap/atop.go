package main

import (
	"errors"
	"fmt"
	"path/filepath"
)

const atopConfigPath = "/etc/default/atop"

type atopOptions struct {
	apply     bool
	sudoReady bool
}

func (a app) runAtop(opts atopOptions) error {
	fmt.Printf("Atop recorder target:\n  interval: 10 seconds\n  retention: 7 daily logs\n  path:      /var/log/atop\n  mode:      %s\n\n", modeName(opts.apply))

	if !commandExists("atop") {
		fail("atop command missing")
		if !opts.apply {
			return nil
		}
		if !opts.sudoReady {
			if err := requireSudo(); err != nil {
				return err
			}
			opts.sudoReady = true
		}
		if err := run("sudo", "pacman", "-S", "--needed", "--noconfirm", "atop"); err != nil {
			return err
		}
		if !commandExists("atop") {
			return errors.New("atop command is still missing after package installation")
		}
	}

	source := filepath.Join(a.repo, "bootstrap", "atop", "default")
	configCurrent := filesEqual(source, atopConfigPath)
	if configCurrent {
		pass("atop samples every 10 seconds and retains 7 daily logs")
	} else {
		fail("atop recorder config is missing or stale")
	}

	serviceEnabled := commandOK("systemctl", "is-enabled", "--quiet", "atop.service")
	timerEnabled := commandOK("systemctl", "is-enabled", "--quiet", "atop-rotate.timer")
	serviceActive := commandOK("systemctl", "is-active", "--quiet", "atop.service")
	if serviceEnabled && timerEnabled && serviceActive {
		pass("atop recorder and daily rotation are enabled and active")
	} else {
		fail("atop recorder or daily rotation is not enabled and active")
	}

	if !opts.apply {
		if !configCurrent || !serviceEnabled || !timerEnabled || !serviceActive {
			fmt.Printf("\nApply atop recorder policy:\n  %s --apply\n",
				shellJoin([]string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "atop"}))
		}
		return nil
	}

	if !opts.sudoReady {
		if err := requireSudo(); err != nil {
			return err
		}
	}
	if !configCurrent {
		if err := run("sudo", "install", "-Dm0644", source, atopConfigPath); err != nil {
			return err
		}
	}
	if err := run("sudo", "systemctl", "enable", "--now", "atop.service", "atop-rotate.timer"); err != nil {
		return err
	}
	if !configCurrent {
		return run("sudo", "systemctl", "restart", "atop.service")
	}
	return nil
}
