let
    lock = builtins.fromJSON (builtins.readFile ../flake.lock);
    compatUrlBase = "https://github.com/edolstra/flake-compat/archive";
    url = "${compatUrlBase}/${lock.nodes.flake-compat.locked.rev}.tar.gz";
    sha256 = lock.nodes.flake-compat.locked.narHash;
    flake-compat = import (fetchTarball { inherit url sha256; });
    compat = flake-compat { src = ../.; };
    defaultNix = compat.defaultNix;
    defNixOutNames = builtins.attrNames defaultNix;
    augmentDefNix = acc: name:
        let output = defaultNix.${name};
            found = output.${builtins.currentSystem} or null;
            outputName = if found != null then name else null;
        in { ${outputName} = found; } // acc;
    currentSystem = builtins.foldl' augmentDefNix {} defNixOutNames;
in compat // {
    defaultNix = compat.defaultNix // { inherit currentSystem; };
}
