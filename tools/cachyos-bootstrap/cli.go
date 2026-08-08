package main

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
)

type bootstrapOptions struct {
	apply         bool
	profile       string
	flake         string
	minimal       bool
	withFlatpaks  bool
	noInstallNix  bool
	noInstallParu bool
	noSwitch      bool
}

type flatpakOptions struct {
	apply   bool
	minimal bool
	profile string
}

type pullGUIConfigOptions struct {
	apply bool
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
	cmd.AddCommand(a.newBootstrapCommand(), a.newDepsCommand(), a.newFirewallCommand(), a.newFlatpaksCommand(), a.newPullGUIConfigCommand(), a.newCleanupCommand(), a.newVerifyCommand())
	return cmd
}

func (a app) newFirewallCommand() *cobra.Command {
	opts := firewallOptions{}
	cmd := &cobra.Command{
		Use:   "firewall",
		Short: "Check or apply LocalSend host firewall policy",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return a.runFirewall(opts)
		},
	}
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "install the UFW app profile and allow LocalSend ports")
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
	cmd.Flags().BoolVar(&opts.minimal, "minimal", false, "skip desktop extras and Flatpak apps")
	cmd.Flags().StringVar(&opts.profile, "profile", "", "deployment profile")
	return cmd
}

func (a app) newFlatpaksCommand() *cobra.Command {
	opts := flatpakOptions{}
	cmd := &cobra.Command{
		Use:   "flatpaks [profile]",
		Short: "Check or install desktop Flatpak apps",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 1 {
				opts.profile = args[0]
			}
			a.fillDefaultFlatpakProfile(&opts)
			return a.runFlatpaks(opts)
		},
	}
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "install missing remote and local Flatpak apps")
	cmd.Flags().BoolVar(&opts.minimal, "minimal", false, "skip Flatpak apps")
	cmd.Flags().StringVar(&opts.profile, "profile", "", "deployment profile")
	return cmd
}

func (a app) newPullGUIConfigCommand() *cobra.Command {
	opts := pullGUIConfigOptions{}
	cmd := &cobra.Command{
		Use:   "pull-gui-config",
		Short: "Import whitelisted GUI-edited config back into the repo",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return a.runPullGUIConfig(opts)
		},
	}
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "copy changed whitelisted GUI config files into home/files")
	return cmd
}

func (a app) newCleanupCommand() *cobra.Command {
	opts := cleanupOptions{}
	cmd := &cobra.Command{
		Use:   "cleanup",
		Short: "Remove safe host packages duplicated by the Nix stack",
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
		Short: "Validate the current Home Manager deployment",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 1 {
				opts.profile = args[0]
			}
			return a.runVerify(opts)
		},
	}
	cmd.Flags().BoolVarP(&opts.verbose, "verbose", "v", false, "print every successful check")
	return cmd
}

func defaultBootstrapOptions() bootstrapOptions {
	return bootstrapOptions{
		profile: "desktop",
	}
}

func addBootstrapFlags(cmd *cobra.Command, opts *bootstrapOptions) {
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "install missing prerequisites and run Home Manager")
	cmd.Flags().StringVar(&opts.profile, "profile", opts.profile, "deployment profile")
	cmd.Flags().StringVar(&opts.flake, "flake", "", "flake output; default follows profile")
	cmd.Flags().BoolVar(&opts.minimal, "minimal", false, "skip desktop extras and Flatpak apps")
	cmd.Flags().BoolVar(&opts.withFlatpaks, "with-flatpaks", false, "install remote and local Flatpak apps in this foreground bootstrap run")
	cmd.Flags().BoolVar(&opts.noInstallNix, "no-install-nix", false, "skip Nix installation/daemon setup")
	cmd.Flags().BoolVar(&opts.noInstallParu, "no-install-paru", false, "skip paru installation")
	cmd.Flags().BoolVar(&opts.noSwitch, "no-switch", false, "do not run Home Manager switch")
}
