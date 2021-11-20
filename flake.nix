{
    description = "Alternative Nix extension of Direnv";

    inputs = {
        flake-parts.url = github:hercules-ci/flake-parts;
        nix-project.url = github:shajra/nix-project;
        lorri = { url = github:nix-community/lorri/canon; flake = false; };
    };

    outputs = inputs@{ self, flake-parts, nix-project, ... }:
        flake-parts.lib.mkFlake { inherit inputs; } ({withSystem, ... }: {
            imports = [ nix-project.flakeModules.nixpkgs ];
            systems = [ "x86_64-linux" ];
            perSystem = { nixpkgs, ... }:
                let build = nixpkgs.stable.extend self.overlays.default;
                in {
                    packages = rec {
                        default = lorelei;
                        inherit (build) lorelei direnv;
                    };
                    apps = rec {
                        default = direnv;
                        direnv = {
                            type = "app";
                            program = "${build.direnv}/bin/direnv";
                        };
                    };
                    legacyPackages.nixpkgs = build;
                };
            flake.overlays.default =
                import nix/overlay.nix inputs withSystem;
        });
}
