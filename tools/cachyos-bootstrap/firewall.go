package main

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	localSendUFWProfileName = "LocalSend"
	localSendUFWProfilePath = "/etc/ufw/applications.d/localsend"
)

type firewallOptions struct {
	apply     bool
	sudoReady bool
}

func (a app) runFirewall(opts firewallOptions) error {
	fmt.Printf("Firewall target:\n  backend: ufw\n  app:     %s\n  ports:   53317/tcp, 53317/udp\n  mode:    %s\n\n",
		localSendUFWProfileName, modeName(opts.apply))

	if !commandExists("ufw") {
		fail("ufw command missing")
		if opts.apply {
			return errors.New("ufw is missing; install host dependencies before applying firewall policy")
		}
		return nil
	}

	source := filepath.Join(a.repo, "bootstrap", "ufw", "localsend")
	profileCurrent := filesEqual(source, localSendUFWProfilePath)
	if profileCurrent {
		pass("UFW application profile `%s` is current", localSendUFWProfileName)
	} else {
		fail("UFW application profile `%s` is missing or stale", localSendUFWProfileName)
	}

	rulesCurrent := localSendUFWRulesPresent()
	if rulesCurrent {
		pass("UFW allows LocalSend discovery and transfer on TCP/UDP 53317")
	} else {
		fail("UFW is missing the LocalSend TCP/UDP 53317 rules")
	}

	if !ufwEnabled() {
		warn("UFW is not enabled; rules can be installed, but this command will not enable the host firewall")
	}

	if !opts.apply {
		if !profileCurrent || !rulesCurrent {
			fmt.Printf("\nApply firewall policy:\n  %s --apply\n",
				shellJoin([]string{filepath.Join(a.repo, "bootstrap", "cachyos.sh"), "firewall"}))
		}
		return nil
	}

	if profileCurrent && rulesCurrent {
		return nil
	}
	if !opts.sudoReady {
		if err := requireSudo(); err != nil {
			return err
		}
	}

	if err := run("sudo", "install", "-Dm0644", source, localSendUFWProfilePath); err != nil {
		return err
	}
	if rulesCurrent {
		return run("sudo", "ufw", "app", "update", localSendUFWProfileName)
	}
	return run("sudo", "ufw", "allow", localSendUFWProfileName)
}

func filesEqual(left, right string) bool {
	leftData, leftErr := os.ReadFile(left)
	rightData, rightErr := os.ReadFile(right)
	return leftErr == nil && rightErr == nil && bytes.Equal(leftData, rightData)
}

func ufwEnabled() bool {
	data, err := os.ReadFile("/etc/ufw/ufw.conf")
	return err == nil && lineHasValue(string(data), "ENABLED", "yes")
}

func localSendUFWRulesPresent() bool {
	if !ufwRulesFileHasLocalSend("/etc/ufw/user.rules") {
		return false
	}
	defaultUFW, err := os.ReadFile("/etc/default/ufw")
	if err == nil && lineHasValue(string(defaultUFW), "IPV6", "yes") {
		return ufwRulesFileHasLocalSend("/etc/ufw/user6.rules")
	}
	return true
}

func ufwRulesFileHasLocalSend(path string) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	text := string(data)
	return strings.Contains(text, "allow tcp 53317") &&
		strings.Contains(text, "allow udp 53317") &&
		strings.Contains(text, "LocalSend")
}

func lineHasValue(text, key, wanted string) bool {
	for _, line := range strings.Split(text, "\n") {
		parts := strings.SplitN(strings.TrimSpace(line), "=", 2)
		if len(parts) != 2 || parts[0] != key {
			continue
		}
		return strings.Trim(strings.TrimSpace(parts[1]), `"'`) == wanted
	}
	return false
}
