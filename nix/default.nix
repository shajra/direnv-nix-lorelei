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

    lorri = nixpkgs-stable.applyPatches {
        name = "lorri-patched";
        src = sources.lorri;
        patches = [./remove_trace.patch];
    };

    overlay = super: self: import sources.nix-project // rec {
        lorri-runtime =
            self.callPackage
            (import "${lorri}/nix/runtime.nix")
            {};
        lorri-eval = {src}:
            (import "${lorri}/src/logged-evaluation.nix")
            { inherit src; runTimeClosure = lorri-runtime; };
        lorri-envrc =
            "${lorri}/src/ops/direnv/envrc.bash";
        direnv-nix-lorelei =
            self.callPackage (import ./direnv-nix-lorelei.nix) {};
    };

    direnv-nix-lorelei = nixpkgs-stable.direnv-nix-lorelei;
    direnv = nixpkgs-stable.direnv;

    lorri-eval = nixpkgs-stable.lorri-eval;
    lorri-envrc = nixpkgs-stable.lorri-envrc;

in {
    inherit
    direnv
    direnv-nix-lorelei
    lorri-envrc
    lorri-eval
    nixpkgs-stable
    nixpkgs-unstable;
}
