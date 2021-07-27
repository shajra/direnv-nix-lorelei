let

    sources = import ./sources;

    pkgs = import sources.nixpkgs-stable {
        config    = {};
        overlays = [overlay];
    };

    lorri-stock = pkgs.applyPatches {
        name = "lorri-stock";
        src = sources.lorri;
        patches = [./env_name_cleanup.patch];
    };

    lorri-patched = pkgs.applyPatches {
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

    direnv-nix-lorelei = pkgs.direnv-nix-lorelei;
    direnv = pkgs.direnv;

    lorri-eval-stock = pkgs.lorri-eval-stock;
    lorri-eval-patched = pkgs.lorri-eval-patched;
    lorri-envrc = pkgs.lorri-envrc;

in {
    inherit
    direnv
    direnv-nix-lorelei
    lorri-envrc
    lorri-eval-stock
    lorri-eval-patched
    pkgs;
}
