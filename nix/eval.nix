suffix: (import ./compat.nix)
    .defaultNix
    .legacyPackages
    ."${builtins.currentSystem}"
    .nixpkgs
    ."lorri-eval-${suffix}"
