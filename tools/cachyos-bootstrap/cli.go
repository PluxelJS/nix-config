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
	noInstallNix  bool
	noInstallParu bool
	noSwitch      bool
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
		profile: "desktop",
	}
}

func addBootstrapFlags(cmd *cobra.Command, opts *bootstrapOptions) {
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "install missing prerequisites and run Home Manager")
	cmd.Flags().StringVar(&opts.profile, "profile", opts.profile, "deployment profile")
	cmd.Flags().StringVar(&opts.flake, "flake", "", "flake output; default follows profile")
	cmd.Flags().BoolVar(&opts.minimal, "minimal", false, "skip desktop extras and Flatpak canaries")
	cmd.Flags().BoolVar(&opts.noInstallNix, "no-install-nix", false, "skip Nix installation/daemon setup")
	cmd.Flags().BoolVar(&opts.noInstallParu, "no-install-paru", false, "skip paru installation")
	cmd.Flags().BoolVar(&opts.noSwitch, "no-switch", false, "do not run Home Manager switch")
}
