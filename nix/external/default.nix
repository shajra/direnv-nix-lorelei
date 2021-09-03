let

    srcs = import ./sources.nix;

    nixpkgs-bootstrap = import srcs.nixpkgs { config = {}; overlays = []; };
    isDarwin = nixpkgs-bootstrap.stdenv.isDarwin;

    nixpkgs-stable-linux = srcs.nixpkgs;
    nixpkgs-stable-darwin = srcs.nixpkgs-darwin;
    nixpkgs-stable =
        if isDarwin then nixpkgs-stable-darwin else nixpkgs-stable-linux;

    srcsMerged = srcs // {
        inherit nixpkgs-stable nixpkgs-stable-linux nixpkgs-stable-darwin;
    };

in builtins.removeAttrs srcsMerged ["nixpkgs" "nixpkgs-darwin"]
