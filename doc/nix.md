- [About this document](#sec-1)
- [How this project uses Nix](#sec-2)
- [Motivation to use Nix](#sec-3)
- [Level of commitment/risk](#sec-4)
- [Installation and setup](#sec-5)
  - [Nix package manager setup](#sec-5-1)
  - [Cache setup](#sec-5-2)
- [Working with Nix](#sec-6)
  - [Searching Nix files](#sec-6-1)
  - [Building Nix expressions](#sec-6-2)
  - [Running commands](#sec-6-3)
  - [Installing and uninstalling programs](#sec-6-4)
  - [Garbage collection](#sec-6-5)
  - [Understanding derivations](#nix-drv)
  - [Lazy evaluation](#sec-6-7)
- [Next steps](#sec-7)


# About this document<a id="sec-1"></a>

This document is included for people somewhat new to Nix. Although the [official Nix documentation](https://nixos.org/learn.html) has gotten substantially better with time, this is an embedded guide to help get started with Nix so it's easier to use the rest of the project.

Note that this document only covers the Nix package manager, not [NixOS](https://nixos.org) (a full Linux operating system built on top of Nix) or [Nix-Darwin](https://daiderd.com/nix-darwin) (a project that gives the benefits of NixOS for MacOS).

# How this project uses Nix<a id="sec-2"></a>

This project uses the [Nix package manager](https://nixos.org/nix) to download all necessary dependencies and build everything from source. In this regard, Nix is helpful as not just a package manager, but also a build tool. Nix helps us get from raw source files to not only built executables, but all the way to a Nix package, which we can install with Nix if we like.

[This project's continuous integration (using GitHub Actions)](https://github.com/shajra/direnv-nix-lorelei/actions) caches built packages at [Cachix](https://cachix.org), a service for caching pre-built Nix packages. If you don't want to wait for a full local build when first using this project, setting up Nix to pull from Cachix is recommended.

Within this project, the various files with a ".nix" extension are Nix files, each of which contains an expression written in the [Nix expression language](https://nixos.org/nix/manual/#ch-expression-language) used by the Nix package manager to specify packages. If you get proficient with this language, you can use these expressions as a starting point to compose your own packages beyond what's provided in this project.

# Motivation to use Nix<a id="sec-3"></a>

When making a new software project, wrangling dependencies can be a chore. For instance, GNU Make's makefiles often depend on executables and libraries that may not yet be available on a system. The makefiles in most projects don't assist with getting these dependencies at usable versions. And when projects document how to get and install dependencies, there can be a lot of room for error.

Nix can build and install projects in a way that's precise, repeatable, and guaranteed not to conflict with anything already installed. Every single dependency needed to build a package is specified in Nix expressions. For each dependency needed to build a package, Nix will download the dependency, build it, and install it as a Nix package for use as a dependency. Nix can even concurrently install multiple versions of any dependency without conflicts.

Every dependency of a Nix package is itself a Nix package. And Nix supports building packages for a variety of languages. Nix picks up where language-specific tooling stops, layering on top of the tools and techniques native to those ecosystems. Since each package is specified by a Nix expression, and because Nix expressions are designed to be composed together to make new ones, we can make our own expressions to specify new packages with dependencies that may not all come from the same language ecosystem.

To underscore how repeatable and precise Nix builds are, it helps to know that Nix uniquely identifies packages by a hash derived from the hashes of requisite dependencies and configuration. This is a recursive hash calculation that assures that the smallest change to even a distant transitive dependency of a package changes its hash. When dependencies are downloaded, they are checked against the expected hash. Most Nix projects (this one included) are careful to pin dependencies to specific versions/hashes. Because of this, when building the same project with Nix on two different systems, we get an extremely high confidence we will get the same output, often bit-for-bit. This is a profound degree of precision relative to other popular package managers.

The repeatability and precision of Nix enables caching services, which for Nix are called *substitutors*. Cachix is one such substitutor. Before building a package, the hash for the package is calculated. If any configured substitutor has a build for the hash, it's pulled down as a substitute. A certificate-based protocol is used to establish trust of substitutors. Between this protocol, and the algorithm for calculating hashes in Nix, you can have confidence that a package pulled from a substitutor will be identical to what you would have built locally.

All of this makes Nix an attractive tool for managing almost any software project.

# Level of commitment/risk<a id="sec-4"></a>

Unless you're on NixOS, you're likely already using another package manager for your operating system already (APT, Yum, etc.). You don't have to worry about Nix or packages installed by Nix conflicting with anything already on your system. Running Nix along side other package managers is safe.

All the files of a Nix package are located under `/nix` a directory, well isolated from any other package manager. Nix won't touch any directories like `/etc` or `/usr/local`. Nix then symlinks files under `/nix` to your home directory under dot-files like `~/.nix-profile`.

Hopefully, this alleviates any worry about installing a complex program on your machine. Uninstallation is nearly as easy as deleting everything under `/nix`.

# Installation and setup<a id="sec-5"></a>

## Nix package manager setup<a id="sec-5-1"></a>

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

## Cache setup<a id="sec-5-2"></a>

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

# Working with Nix<a id="sec-6"></a>

Though covering Nix comprehensively is beyond the scope of this document, we'll go over a few commands illustrating some usage of Nix with this project.

## Searching Nix files<a id="sec-6-1"></a>

Each of the Nix files in this project (files with a ".nix" extension) contains exactly one Nix expression. This expression evaluates to one of the following values:

-   simple primitives and functions
-   *derivations* of packages that can be built and installed with Nix
-   containers of values, allowing a single value to provide multiple values of different types, including more containers of values.

Once you learn the Nix language, you can read these files to see what kind of values they build. We can use the `nix search` command to see what package derivations a Nix expression contains. For example from the root directory of this project, we can execute:

```sh
nix search --file default.nix --no-cache
```

    * direnv (direnv)
      A shell extension that manages your environment
    
    * direnv-nix-lorelei (direnv-nix-lorelei)
      Alternative Nix functions for Direnv

If you don't get the results above, see the [section on understanding derivations](#nix-drv) for an explanation of a likely problem and workaround.

Note that because for extremely large Nix expressions, searching can be slow, `nix search` by default returns results from searching an indexed cache. This cache is updated explicitly (with an `--update-cache` switch) but may be inconsistent with what you really want to search. It can be confusing to get incorrect results due to an inconsistent cache. However, because small local projects rarely have that many package derivations we don't really need the cache, and can bypass it with the `--no-cache` switch, as used above. This guarantees accurate results that are fast enough. So for the purposes of this project, it's recommended to always use `--no-cache`.

The output of `nix search` is formatted as

    * attribute-path (name-of-package)
      Short description of package

*Attribute paths* are used to select values from Nix sets that might be nested. A dot delimits *attributes* in the path. For instance an attribute path of `a.b` selects a value from a set with an `a` attribute that has set with a `b` attribute, that then has the value to select.

If the Nix expression we're searching evaluates to a single derivation (not in a container), the attribute path will be missing from the `nix search` result.

Many Nix commands evaluate Nix files. If you specify a directory instead, the command will look for a `default.nix` file within to evaluate. So from the root directory of this project, we could use `.` instead of `default.nix`:

```sh
nix search --file . --no-cache
```

In the remainder of this document, we'll use `.` instead of `default.nix` since this is conventional for Nix.

## Building Nix expressions<a id="sec-6-2"></a>

The following result is one returned by our prior execution of `nix search --no-cache --file .`:

    * direnv-nix-lorelei (direnv-nix-lorelei)
      Alternative Nix functions for Direnv

We can see that a package named "direnv-nix-lorelei" can be accessed with the `direnv-nix-lorelei` attribute path in the Nix expression in the project root's `default.nix`. Not shown in the search results above, this package happens to provide the library `nix-alt.sh`.

We can build this package with `nix build` from the project root:

```sh
nix build --file . direnv-nix-lorelei
```

The positional arguments to `nix build` are *installables*, which can be referenced by attribute paths. If you supply none then all derivations found are built by default.

All packages built by Nix are stored in `/nix/store`. Nix won't rebuild packages found there. Once a package is built, its content in `/nix/store` is read-only (until the package is garbage collected, discussed later).

After a successful call of `nix build`, you'll see one or more symlinks for each package requested in the current working directory. These symlinks by default have a name prefixed with "result" and point back to the respective build in `/nix/store`:

```sh
readlink result*
```

    /nix/store/q44il55npbs3pj2zpg0f828hy6miysn0-direnv-nix-lorelei

Following these symlinks, we can see the files the project provides:

```sh
tree -l result*
```

    result
    └── share
        └── direnv-nix-lorelei
            └── nix-lorelei.bash
    
    2 directories, 1 file

It's common to configure these "result" symlinks as ignored in source control tools (for instance, for Git within a `.gitignore` file).

`nix build` has a `--no-link` switch in case you want to build packages without creating "result" symlinks. To get the paths where your packages are located, you can use `nix path-info` after a successful build:

```sh
nix path-info --file . direnv-nix-lorelei
```

    /nix/store/q44il55npbs3pj2zpg0f828hy6miysn0-direnv-nix-lorelei

## Running commands<a id="sec-6-3"></a>

We can run commands in Nix-curated environments with `nix run`. Nix will take executables found in packages, put them in an environment's `PATH`, and then execute a user-specified command.

With `nix run`, you don't even have to build the package first with `nix build` or mess around with "result" symlinks. `nix run` will build the project if it's not yet been built.

For example, to get the help message for the `direnv` executable provided by the `direnv` package selected by the `direnv` attribute path from `.`, we can call the following:

```sh
nix run \
    --file . \
    direnv \
    --command direnv --help
```

    direnv v2.28.0
    Usage: direnv COMMAND [...ARGS]
    
    Available commands
    ------------------
    …

Thus far, the argument of the `--file` switch has always referenced a Nix file on our local filesystem. However, it's possible to reference a Nix expression downloaded from the internet. The Nix ecosystem is supported by a giant GitHub repository of Nix expressions called [Nixpkgs](https://github.com/NixOS/nixpkgs). Special branches of this repository are considered *channels* in the Nix ecosystem. A Nixpkgs branch of "nixos-21.05" can be referenced by "channel:nixos-21.05" for `nix` subcommands that accept a `--file` switch.

Again, as with `nix build`, attribute paths are specified as positional arguments to select packages.

The command to run is specified after the `--command` switch. `nix run` runs the command in a shell set up with a `PATH` environment variable including all the `bin` directories provided by the selected packages.

`nix run` also supports an `--ignore-environment` flag that restricts `PATH` to only packages selected, rather than extending the `PATH` of the caller's environment. With `--ignore-environment`, the invocation is more sandboxed.

## Installing and uninstalling programs<a id="sec-6-4"></a>

We've seen that we can build programs with `nix build` and then execute them using the "result" symlink (`result/bin/*`). Additionally, we've seen that you can run programs with `nix run`. But these additional steps and switches/arguments can feel extraneous. It would be nice if we could just have the programs on our `PATH`. This is what `nix-env` is for.

`nix-env` maintains a symlink tree, called a *profile*, of installed programs. The active profile is pointed to by a symlink at `~/.nix-profile`. By default, this profile points to `/nix/var/nix/profiles/per-user/$USER/profile`. But you can point your `~/.nix-profile` to any writable location with the `--switch-profile` switch:

```sh
nix-env --switch-profile /nix/var/nix/profiles/per-user/$USER/another-profile
```

This way, you can just put `~/.nix-profile/bin` on your `PATH`, and any programs installed in your currently active profile will be available for interactive use or scripts.

We can query what's installed in the active profile with the `--query` switch:

```sh
nix-env --query
```

To install the `nix-alt.sh` library, which is accessed by the `direnv-nix-lorelei` in our top-level `default.nix` file, we'd run the following:

```sh
nix-env --install --file . --attr direnv-nix-lorelei 2>&1
```

    installing 'direnv-nix-lorelei'

We can see this installation by querying what's been installed:

```sh
nix-env --query
```

    direnv-nix-lorelei

And if we want to uninstall a program from our active profile, we do so by its name, in this case "direnv-nix-lorelei":

```sh
nix-env --uninstall direnv-nix-lorelei 2>&1
```

    uninstalling 'direnv-nix-lorelei'

Note that we've installed our package using its attribute path (`direnv-nix-lorelei`) within the referenced Nix expression. But we uninstall it using the package name ("direnv-nix-lorelei"), which may or may not be the same as the attribute path. When a package is installed, Nix keeps no reference to the expression that evaluated to the derivation of the installed package. The attribute path is only relevant to this expression. In fact, two different expressions could evaluate to the same derivation, but use different attribute paths. This is why we uninstall packages by their package name.

Also, if you look at the location for your profile, you'll see that Nix retains the symlink trees of previous generations of your profile. In fact you can even rollback to a previous profile with the `--rollback` switch. You can delete old generations of your profile with the `--delete-generations` switch.

See the [documentation for `nix-env`](https://nixos.org/nix/manual/#sec-nix-env) for more details.

## Garbage collection<a id="sec-6-5"></a>

Every time you build a new version of your code, it's stored in `/nix/store`. There is a command called `nix-collect-garbage` that purges unneeded packages. Programs that should not be removed by `nix-collect-garbage` can by found by starting with symlinks stored as *garbage collection (GC) roots* under three locations:

-   `/nix/var/nix/gcroots`
-   `/nix/var/nix/profiles`
-   `/nix/var/nix/manifests`.

For each package, Nix is aware of all references back to other packages in `/nix/store`, whether in text files or binaries. This helps Nix assure that dependencies of packages linked as GC roots won't be deleted.

Each "result" symlink created by a `nix build` invocation has a symlink in `/nix/var/nix/gcroots/auto` pointing back it. So we've got symlinks in `/nix/var/nix/gcroots/auto` pointing to "result" symlinks in our projects, which then reference the actual built project in `/nix/store`. These chains of symlinks prevent packages built by `nix build` from being garbage collected.

If you want a package you've built with `nix build` to be garbage collected, delete the "result" symlink created before calling `nix-collect-garbage`. Breaking symlink chains under `/nix/var/nix/gcroots` removes protection from garbage collection. `nix-collect-garbage` will clean up broken symlinks when it runs.

Note that everything under `/nix/var/nix/profiles` is considered a GC root as well. This is why users by convention use this location to store their `nix-env` profiles.

Also, note if you delete a “result\*” link and call `nix-collect-garbage`, though some garbage may be reclaimed, you may find that an old `nix-env` profile is keeping the program alive. As a convenience, `nix-collect-garbage` has a `--delete-old` switch that will delete these old profiles (it just calls `nix-env --delete-generations` on your behalf).

It's also good to know that `nix-collect-garbage` won't delete packages referenced by any running processes. In the case of `nix run` no garbage collection root symlink is created under `/nix/var/nix/gcroots`, but while `nix run` is running `nix-collect-garbage` won't delete packages needed by the running command. However, once the `nix run` call exits, any packages pulled from a substitutor or built locally are candidates for deletion by `nix-collect-garbage`. If you called `nix run` again after garbage collecting, those packages may be pulled or built again.

## Understanding derivations<a id="nix-drv"></a>

We haven't detailed what happens when we build a Nix expression that evaluates to a package derivation. There are two important steps:

1.  *instantiating* the derivation
2.  *realizing* the instantiated derivation, which builds the final package.

An instantiated derivation is effectively a script stored in `/nix/store` that Nix can run to build the final package (which also ends up in `/nix/store`). These instantiated derivations have a ".drv" extension, and if you look in `/nix/store` you may find some. Instantiated derivations have references to all necessary build dependencies, also in `/nix/store`, which means that everything is physically in place in `/nix/store` to build the package (no network connectivity is needed to realize an instantiated derivation).

Note that both `nix build` and `nix run` perform both instantiation and realization of a derivation, so for the most part, we don't have to worry about the difference between instantiating and realizing a derivation.

However, you may encounter a Nix expression where `nix search` returns nothing, though you're sure that there are derivations to select out. In this case, the Nix expression is using an advanced technique that unfortunately hides attributes from `nix search` until some derivations are instantiated into `/nix/store`. We can force the instantiation of these derivations without realizing their packages with the following command:

```sh
nix show-derivation --file default.nix
```

Once these derivations are instantiated, you may get more results with `nix search` for the occasional Nix expression that uses some advanced techniques.

## Lazy evaluation<a id="sec-6-7"></a>

We haven't made a big deal of it, but the Nix language is *lazily evaluated*. This allows a single Nix expression to refer to several thousand packages, but without requiring us to evaluate everything when selecting out packages by attribute paths. In fact, the entire NixOS operating system is based heavily on a single single expression managed in a Git repository called [Nixpkgs](https://github.com/NixOS/nixpkgs).

# Next steps<a id="sec-7"></a>

This document has covered a fraction of Nix usage, hopefully enough to introduce Nix in the context of [this project](../README.md).

An obvious place to start learning more about Nix is [the official documentation](https://nixos.org/learn.html). The author of this project also maintains another project with [a small tutorial on Nix](https://github.com/shajra/example-nix/tree/master/tutorials/0-nix-intro). This tutorial covers the Nix expression language in more detail.

All the commands we've covered have more switches and options. See the respective man pages for more. Also, we didn't cover `nix-shell`, which can be used for setting up development environments. And we didn't cover much of [Nixpkgs](https://github.com/NixOS/nixpkgs), the gigantic repository of community-curated Nix expressions.

The Nix ecosystem is vast. This project and documentation illustrates just a small sample of what Nix can do.
