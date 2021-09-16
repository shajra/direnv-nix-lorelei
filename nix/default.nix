{ externalOverrides ? {}
}:

let

    external = import ./external // externalOverrides;

    nix-project = import external.nix-project;

    nixpkgs = import external.nixpkgs-stable {
        config    = {};
        overlays = [overlay];
    };

    lorri-stock = nixpkgs.applyPatches {
        name = "lorri-stock";
        src = external.lorri;
        patches = [./env_name_cleanup.patch];
    };

    lorri-patched = nixpkgs.applyPatches {
        name = "lorri-patched";
        src = external.lorri;
        patches = [
          ./remove_trace.patch
          ./env_name_cleanup.patch
        ];
    };

    overlay = self: super: nix-project // rec {
        lorri-runtime =
            super.callPackage
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
            super.callPackage (import ./direnv-nix-lorelei.nix) {};
        direnv-nix-lorelei-home = ./home.nix;
    };

    distribution = {
        inherit (nixpkgs)
        direnv
        direnv-nix-lorelei
        direnv-nix-lorelei-home;
    };

    build = distribution // {
        inherit (nixpkgs)
        lorri-eval-patched
        lorri-eval-stock
        ;
    };

in { inherit build distribution nix-project nixpkgs; }
