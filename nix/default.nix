let

    sources = import ./sources;

    nixpkgs-stable = import sources.nixpkgs-stable {
        config    = {};
        overlays = [overlay];
    };

    nixpkgs-unstable = import sources.nixpkgs-unstable {
        config    = {};
        overlays = [overlay];
    };

    lorri-stock = nixpkgs-stable.applyPatches {
        name = "lorri-stock";
        src = sources.lorri;
        patches = [./env_name_cleanup.patch];
    };

    lorri-patched = nixpkgs-stable.applyPatches {
        name = "lorri-patched";
        src = sources.lorri;
        patches = [
          ./remove_trace.patch
          ./env_name_cleanup.patch
        ];
    };

    overlay = super: self: import sources.nix-project // rec {
        lorri-runtime =
            self.callPackage
            (import "${lorri-stock}/nix/runtime.nix")
            {};
        lorri-eval-stock = {src}:
            (import "${lorri-stock}/src/logged-evaluation.nix")
            { inherit src; runTimeClosure = lorri-runtime; };
        lorri-eval-patched = {src}:
            (import "${lorri-patched}/src/logged-evaluation.nix")
            { inherit src; runTimeClosure = lorri-runtime; };
        lorri-envrc =
            "${lorri-stock}/src/ops/direnv/envrc.bash";
        direnv-nix-lorelei =
            self.callPackage (import ./direnv-nix-lorelei.nix) {};
    };

    direnv-nix-lorelei = nixpkgs-stable.direnv-nix-lorelei;
    direnv = nixpkgs-stable.direnv;

    lorri-eval-stock = nixpkgs-stable.lorri-eval-stock;
    lorri-eval-patched = nixpkgs-stable.lorri-eval-patched;
    lorri-envrc = nixpkgs-stable.lorri-envrc;

in {
    inherit
    direnv
    direnv-nix-lorelei
    lorri-envrc
    lorri-eval-stock
    lorri-eval-patched
    nixpkgs-stable
    nixpkgs-unstable;
}
