- [About this project](#sec-1)
  - [About Direnv](#sec-1-1)
  - [About Nix integration](#sec-1-2)
- [Installation](#sec-2)
  - [Nix package manager setup](#sec-2-1)
  - [Cache setup](#sec-2-2)
  - [Installation via `nix-env`](#install-nixenv)
    - [Direnv installation](#sec-2-3-1)
    - [Installing Lorelei](#sec-2-3-2)
  - [Installation via Home Manager](#install-homemanager)
- [Configuration and usage](#sec-3)
  - [Terminal and editor configuration](#sec-3-1)
  - [Per-project configuration](#sec-3-2)
- [Prior art](#sec-4)
- [Known limitations](#sec-5)
- [Release](#sec-6)
- [License](#sec-7)
- [Contribution](#sec-8)

[![img](https://github.com/shajra/direnv-nix-lorelei/workflows/CI/badge.svg)](https://github.com/shajra/direnv-nix-lorelei/actions)

# About this project<a id="sec-1"></a>

Lorelei provides a [Direnv](https://direnv.net) extension to configure directory-level environment variables from a [Nix](https://nixos.org/nix) expression. This support improves upon the built-in Nix support of Direnv with the following features:

-   The calculation of your project's environment variables can be cached to avoid loading time.

-   The cache of environment variables can be configured to be invalidated when
    -   the content of a file changes
    -   a file's modification time changes (even if content does not)
    -   a per-project `.direnv/delete_to_rebuild` file is deleted.

-   Additionally files to watch for cache invalidation can be automatically detected, though this detection is not comprehensive.

-   Programs referenced by active environment variables are prevented from being garbage collected by Nix.

-   You can also save a configurable number of previous environments from being garbage collected.

Note, Lorelei only works with projects that have a Nix file that can be called with `nix-shell` (typically called "shell.nix"). For projects that provide a Nix environment with the not-yet-released Nix flakes feature, please consider using the `use_flake` function of the [nix-direnv](https://github.com/nix-community/nix-direnv) project, which you can use concurrently with Lorelei with no conflicts.

## About Direnv<a id="sec-1-1"></a>

When we go into a project's directory we often want certain environment variables set specifically to a project's needs. A very common environment variable to specify per-project is `PATH` to make available development tools needed by a project. Different projects may depend on conflicting tools, such as different versions of a compiler.

Direnv targets solving this problem. Once you set it up, you can hook your terminal shell to automatically load variables based upon your current working directory. Then, when you `cd` into the directory, the variables change automatically.

Additionally, many popularly used programming editors have Direnv extensions/plugins. Rather than use editor-specific configuration to treat each project differently, we can configure these projects with Direnv. Any editor configured with a Direnv extension/plugin will then pick up the right environment based on the project of the edited file.

Once we set up our editors and shells with Direnv, we can configure our project-specific environment in one place with Direnv. Also, since Nix is far less popularly used than Direnv, we don't have to worry about unsupported Nix integration with our editors or shells. Lorelei can provide all the Nix support we need for Direnv.

## About Nix integration<a id="sec-1-2"></a>

Nix is a package manager (in the same sense as APT, RPM, Homebrew, or Chocolatey). As a package manager, Nix helps us get tools and libraries installed on our system. Nix goes a bit farther, by providing us some facilities to help us get these tools set up in a local environment called a *Nix shell*.

We typically go into a directory with with a specially configured `shell.nix` file, and execute `nix-shell` to enter into an interactive Bash session with environment variables set up for working in our project.

Direnv can help us get rid of the extra step of having to call `nix-shell`.

Direnv actually comes with Nix support built-in, but this support is very basic. Specifically, it has no caching of calculated environments, or protection required dependencies from being garbage collected by Nix.

See [the provided documentation on Nix](doc/nix.md) for more on what Nix is, why we're motivated to use it, and how to get set up with it for this project. Not covered in this documentation are details on how to set make a Nix expression to set up a Nix shell. There's just a lot of ways to do this for each programming langauge, and the [official Nixpkgs manual](https://nixos.org/nixpkgs/manual) is the best resource.

# Installation<a id="sec-2"></a>

Lorelei should work with either GNU/Linux or MacOS operating systems. Before we can configure specific projects/directories to use Direnv and Lorelei, we need to do the following:

1.  install and configure Nix, if we haven't already
2.  install Direnv
3.  install Lorelei
4.  create a symlink under `$XDG_CONFIG_HOME/direnv/lib` pointing to Lorelei's installed Bash functions.

Beyond the installation of Nix, we have two ways to install packages and create the symlink:

-   use `nix-env` and create the symlink ourselves
-   use [Home Manager](https://github.com/nix-community/home-manager) to manage both packages and home directory configuration (including the symlink under under `$XDG_CONFIG_HOME/direnv/lib`).

The following sections cover both these options. Home Manager introduces its own complexity and added work for configuration. But there can be a nice payoff if you opt to use Home Manager to manage more than just Lorelei.

## Nix package manager setup<a id="sec-2-1"></a>

> **<span class="underline">NOTE:</span>** You don't need this step if you're running NixOS, which comes with Nix baked in.

If you don't already have Nix, [the official installation script](https://nixos.org/learn.html) should work on a variety of UNIX-like operating systems:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

If you're on a recent release of MacOS, you will need an extra switch:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon \
    --darwin-use-unencrypted-nix-store-volume
```

After installation, you may have to exit your terminal session and log back in to have environment variables configured to put Nix executables on your `PATH`.

The `--daemon` switch installs Nix in the recommended multi-user mode. This requires the script to run commands with `sudo`. The script fairly verbosely reports everything it does and touches. If you later want to uninstall Nix, you can run the installation script again, and it will tell you what to do to get back to a clean state.

The Nix manual describes [other methods of installing Nix](https://nixos.org/nix/manual/#chap-installation) that may suit you more.

## Cache setup<a id="sec-2-2"></a>

It's recommended to configure Nix to use shajra.cachix.org as a Nix *substitutor*. This project pushes built Nix packages to [Cachix](https://cachix.org) as part of its continuous integration. Once configured, Nix will pull down these pre-built packages instead of building them locally (potentially saving a lot of time). This augments the default substitutor that pulls from cache.nixos.org.

You can configure shajra.cachix.org as a substitutor with the following command:

```sh
nix run \
    --file https://cachix.org/api/v1/install \
    cachix \
    --command cachix use shajra
```

Cachix is a service that anyone can use. You can call this command later to add substitutors for someone else using Cachix, replacing "shajra" with their cache's name.

If you've just run a multi-user Nix installation and are not yet a trusted user in `/etc/nix/nix.conf`, this command may not work. But it will report back some options to proceed.

One option sets you up as a trusted user, and installs Cachix configuration for Nix locally at `~/.config/nix/nix.conf`. This configuration will be available immediately, and any subsequent invocation of Nix commands will take advantage of the Cachix cache.

You can alternatively configure Cachix as a substitutor globally by running the above command as a root user (say with `sudo`), which sets up Cachix directly in `/etc/nix/nix.conf`. The invocation may give further instructions upon completion.

## Installation via `nix-env`<a id="install-nixenv"></a>

This section covers the option of installing packages with `nix-env`, and not with Home Manager. If you're not as familiar with `nix-env`, you may be interested in this project's [supplemental documentation on Nix](doc/nix.md).

If you've installed Home Manager, you may skip this section and try out [the next section on installation with Home manager](#install-homemanager).

### Direnv installation<a id="sec-2-3-1"></a>

If you don't already have Direnv installed, you have the option of installing Direnv from this project (otherwise, you can skip this step):

```sh
nix-env --install --file . --attr direnv 2>&1
```

    installing 'direnv-2.28.0'

If you have `~/.nix-profile/bin` in your environment's `PATH`, you should be able to call the `direnv` executable. Here's a simple way of testing its availability.

```sh
direnv version
```

    2.28.0

### Installing Lorelei<a id="sec-2-3-2"></a>

This project provides a Nix expression in the project's root `default.nix` file. From the root directory of a checkout of the project, you can install Lorelei as follows:

```sh
nix-env --install --file . --attr direnv-nix-lorelei 2>&1
```

    installing 'direnv-nix-lorelei'

This installation doesn't install a binary, but instead a shell library that you use as configuration for Direnv. Given a typical installation of Nix, this installation should be into the active Nix profile at `~/.nix-profile`. We can tie this library to Direnv with a symlink:

```sh
mkdir --parents ~/.config/direnv/lib
ln --force --symbolic --no-target-directory \
    ~/.nix-profile/share/direnv-nix-lorelei/nix-lorelei.bash \
    ~/.config/direnv/lib/nix-lorelei.sh
```

## Installation via Home Manager<a id="install-homemanager"></a>

This section is for those those who are interested in Home Manager, and skipped [the prior section](#install-nixenv) on how to install the needed packages with `nix-env` and create the needed symlink directly with `ln`.

Detailed instructions on the installation of Home Manager are beyond the scope of this document. Please refer to [Home Manager's manual](https://rycee.gitlab.io/home-manager/).

Home Manager is configured with NixOS-style modules. These modules are Nix functions of a certain form. Modules can import other modules by their path. Some modules provide an configuration options, which are then imported by other modules on the user's side where these options are then employed to configure a particular machine.

In our case, this project provides a module at the *attribute path* `direnv-nix-lorelei-home`. To configure a machine with Lorelei using Home Manager, we'll import this module, and then enable the provided options. Here's an commented example of such a configuration:

```nix
{ config, pkgs, lib, ... }:

let

    # First we have to get the Lorelei source code from GitHub.

    # Unfortunately, can't use pkgs from above (infinite recursion)
    pkgs-bootstrap = import <nixpkgs> { config = {}; overlays = []; };

    lorelei-source = pkgs-bootstrap.fetchFromGitHub {
	owner = "shajra";
	repo = "direnv-nix-lorelei";

	# This is example Git commit ID to pin to. Choose another to upgrade to
	# a later version of Lorelei.
	rev = "8310119578f9bcedb1e4ca2580d3b11bd7d214f2";

	# Use pkgs.lib.fakeSha256 the first time using a new rev with Home
	# Manager, which will then report back the real value to use. A real
	# value will look something like this: sha256 =
	# "198h7ryqdv0h9lv3sixqxzdl8wf57lsvzzm8viipmk4pb0lsyckh";
	sha256 = lib.fakeSha256;
    };

    # Then we access the module it provides.
    module-lorelei = (import lorelei-source).direnv-nix-lorelei-home;

in

# Here's where we configure options provided by imported modules. As is typical,
# the final modules used to configure a machine don't create more options.
{
    # Here our configuration module imports the module Lorelei provides.
    imports = [ module-lorelei ];

    # Home manager already has a module that allows us to include Direnv on our
    # user's PATH.
    programs.direnv.enable = true;

    # Here we enable the option to have Home Manager set up the symlink under
    # $XDG_CONFIG_HOME/direnv/lib to enable Lorelei's usage with Direnv.
    programs.direnv-nix-lorelei.enable = true;
}
```

Not completely illustrated in the above example, the Lorelei Home Manager module provides two options:

-   `programs.direnv-nix-lorelei.enable`: to install Lorelei and configure Direnv to use it.
-   `programs.direnv-nix-lorelei.package`: in case you want to specify another version of Lorelei to use on the machine.

If you're curious, you can read [the source code of the module](nix/home.nix) to see the specifications for these options.

The example above has you going through a step to use `lib.fakeSha256` to get the real hash for Lorelei. These hashes are an important part of Nix's model of trusted code, but managing them when updating dependencies can be a chore. Eventually [Nix Flakes](https://nixos.wiki/wiki/Flakes) will release, which will help with that. In the meantime, you may be interested in the [Niv](https://github.com/nmattia/niv) project to manage these hashes when updating dependencies.

If further interested, you may like looking at [a larger example](https://github.com/shajra/shajra-provisioning/blob/master/home/modules/base/default.nix) of Home Manager configuration of much more than just Lorelei.

# Configuration and usage<a id="sec-3"></a>

## Terminal and editor configuration<a id="sec-3-1"></a>

If you're absolutely new to Direnv, we won't get any benefit from the configuration described in this document until we integrate Direnv with either our terminal's shell, our editor of choice, or both.

We delegate to the [official Direnv documentation](https://direnv.net/#docs) on how to do this configuration. Specifically, have a look at

-   [hooking Direnv into your preferred shell](https://direnv.net/docs/hook.html)
-   the [Direnv wiki for pages about editor integration](https://github.com/direnv/direnv/wiki#editor-integration).

## Per-project configuration<a id="sec-3-2"></a>

If you have a project that can be used to enter a Nix shell with a call like

```sh
nix-shell "$NIX_FILE"
```

for some file `$NIX_FILE`, then at the root of the project you can create a `.envrc` to get started with Direnv:

```sh
echo "use_nix_gcrooted -a \"$NIX_FILE\"" > .envrc
```

As with `nix-shell` specifying a Nix file as a positional argument is optional if you're file is called `shell.nix`. Furthermore, if you don't use `shell.nix`, but use `default.nix` it is also optional.

Finally, we can activate the configuration (Direnv has some security measures to prevent abuse from running arbitrary scripts):

```sh
direnv allow
```

At this point, if you have your terminal and editor configured to use Direnv, you should experience per-project environments serviced by Direnv.

To learn more more about Lorelei's options, we can source the script and run the function outside Direnv. However, we need to be in a Bash shell:

```sh
bash -c "
    . ~/.nix-profile/share/direnv-nix-lorelei/nix-lorelei.bash
    use_nix_gcrooted --help
"
```

    USAGE: use_nix_gcrooted [OPTION]... [FILE]
    
    DESCRIPTION:
    
        A replacement for Direnv's use_nix.  This function, will make
        sure calculated Nix expressions are GC rooted with Nix.  By
        default the calculated environment is also cached, which is
        useful for Nix expressions that have costly evaluations.  To
        invalidate the cache, files can be watched either by their
        content hash or their modification time.  You can also delete
        .direnv/delete_to_rebuild to invalidate the cache.
    
    OPTIONS:
    
        -h --help                print this help message
        -a --auto-watch-content  watch autodetected files for contect
                                 changes
        -A --auto-watch-mtime    watch autodetected files for
                                 modification times
        -d --auto-watch-deep     deeper searching for -a and -A options
        -w --watch-content PATH  watch a file's content for changes
        -W --watch-mtime PATH    watch a file's modification time
        -C --ignore-cache        recompute new environment every time
        -k --keep-last NUM       protect last N caches from GC
                                 (default 5)

Direnv needs to know when to consider recalculating an environment's variables. To do this, we need to register files to watch for changes. This is what the "watch" switches above help specify.

With the `--auto-watch-content` and `--auto-watch-mtime` switches, you don't have to worry about which files to watch for changes. You can either watch these files when their modifications time change, or when their content actually changes (touching a file changes its modification time, but not its content).

The `--auto-watch-content` and `--auto-watch-mtime` switches catch a good amount of Nix files, but won't catch everything you might have the idea to watch. If you want to specify files to watch explicitly, you can use the `--watch-content` and `--watch-mtime` switches.

You can use the `--auto-watch-deep` switch to have the auto-watching features look a little deeper for files to watch. However, the evaluation time you'll face for an not-yet-cached environment will be notably longer for this deeper search (possibly twice as long). Note auto-watching without the `--auto-watch-deep` switch shouldn't add much evaluation overhead, so you should be able to use the normal shallower auto-detection without worrying about a slowdown.

If for some (unlikely) reason, you want the benefits of protection from Nix garbage collection, but not cache the evaluation of environments, you can use `--ignore-cache`. Note, that you still need to specify files to watch for changes. With `--ignore-cache`, you'll recalculate the Nix expression for your project every time these watched files trigger Direnv to recalculate an environment.

Lorelei keeps the last five environments from being garbage collected. You can change this with `--keep-last`.

And finally, if you ever feel like you want to dump your cached environment and recalculate everything, just delete `.direnv/delete_to_rebuild`, which will be next to your project's `.envrc` file.

Lorelei's metadata for your project is in two places:

-   your project's `.direnv` directory
-   your user's GC root directory: `/nix/var/nix/gcroots/per-user/$USER`

You can delete this data to start fresh.

The symlinks in the GC root directory have human readable names to assist manual curation if you need it.

# Prior art<a id="sec-4"></a>

There are four projects that were considered before writing Lorelei:

-   [Lorri](https://github.com/target/lorri)
-   [Sorri](https://github.com/nmattia/sorri)
-   [Nix-direnv](https://github.com/nix-community/nix-direnv)
-   [Nixify](https://github.com/kalbasit/nur-packages/blob/master/pkgs/nixify/envrc)

Lorelei should subsume the features of all of these projects with the exception of Lorri's approach to calculating Direnv environments as a background process. You can think of the name "Lorelei" as a pun of "Lorri-lite," but "Lorelei" is also the name of a [Pogue's song](https://www.youtube.com/watch?v=VDw81PRP2SQ) you may enjoy.

All of these different projects can save on the evaluation time of calculating a Nix expression by caching the Direnv environment. And all of these projects have some facility to protect dependencies referenced by Direnv environments from Nix's garbage collection.

Lorri is the heaviest of these options. To use it, you start a daemon process that in the background watches files for changes and evaluates/builds environments. This way, the environment is ready before you actually enter the project.

Also Lorri inspects Nix's build log to automatically detect which files need to be watched for changes. Unfortunately, this often misses useful files to watch in a project.

Running a background process can be a heavy extra process, and introduces the surface area of complexity and exposure to defects (though the Lorri committers have been committed to fixing them). All of the other projects are lighter-weight than Lorri in this regard. They are just scripts with no requirements on a background process.

Sorri copies a lot of code from Lorri, but removes the background process. So when you enter a Direnv directory, you will always experience the evaluation time of calculating a not-yet-cached Direnv environment. With Lorri this evaluation occurs in the background.

Lorelei is different from Sorri in two main ways:

-   Lorelei gives much more control of cache invalidation beyond the auto-detection of files to watch for changes. These approaches are inspired by Nix-direnv and Nixify.

-   Rather than copying code from Lorri, we actually call Lorri code directly as a library.

Lorri has been relatively active about refining the approach to calculating a Direnv environment, more so than any of the other projects. Sorri copies code, but leads to more work porting changes from Lorri to Sorri. Lorelei uses Nix to use Lorri's code directly. This eases maintenance, but does mean that you *have* to install Lorelei with Nix. However, this is not a bad idea, because Lorelei rigorously pins all of its dependencies, all the way down to `coreutils`. So by installing Lorelei with Nix, we get more precision.

# Known limitations<a id="sec-5"></a>

There's two known limitations of Lorelei:

-   Your project must have a Nix file that can be run with `nix-shell`.
-   Nix flakes aren't supported (yet).

Lorelei delegates strongly to Lorri, so the limitation of requiring an explicit Nix file to import stems from that. This is not to say that this limitation can't be improved upon in the future.

However, we probably don't want to support something like `nix-shell`'s `--packages` switch. This feature of `nix-shell` is generally discouraged by the Nix community because its implementation has a lot of non-intuitive warts. Nix will soon release a `nix shell` command that has the potential to more properly replace the functionality that `nix-shell`'s `--packages` switch provides. When this occurs, both the Lorri and Lorelei can reevaluate their respective implementation strategies.

Also, soon to be released in a new version of Nix are [Nix flakes](https://nixos.wiki/wiki/Flakes). If you don't know what flakes are, you may want to wait until they stabilize and are officially released. If you're an early adopter of flakes, the [Nix-direnv](https://github.com/nix-community/nix-direnv) project has support for Nix flakes with it's `use_flake` function. Lorelei can be installed and used concurrently with other projects offering similar functionality (Lorri, Nix-direnv, and the rest). You just make different calls in your project's `.envrc` files. No core contributor of Lorelei is using this unreleased version of Nix supporting flakes, so we didn't want to provide something we had not tested ourselves.

# Release<a id="sec-6"></a>

The "main" branch of the repository on GitHub has the latest released version of this code. There is currently no commitment to either forward or backward compatibility.

"user/shajra" branches are personal branches that may be force-pushed to. The "main" branch should not experience force-pushes and is recommended for general use.

# License<a id="sec-7"></a>

All files in this "direnv-nix-lorelei" project are licensed under the terms of GPLv3 or (at your option) any later version.

Please see the [./COPYING.md](./COPYING.md) file for more details.

# Contribution<a id="sec-8"></a>

Feel free to file issues and submit pull requests with GitHub.

There is only one author to date, so the following copyright covers all files in this project:

Copyright © 2020 Sukant Hajra
