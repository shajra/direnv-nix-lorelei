{ config, lib, pkgs, ... }:

with lib;

let cfg = config.programs.direnv-nix-lorelei;

in {
    options = {
        programs.direnv-nix-lorelei = {
            enable = mkOption {
                type = types.bool;
                default = false;
                defaultText = "false";
                description = ''
                    Whether to enable direnv-nix-lorelei.
                '';
            };
            package = mkOption {
                type = types.package;
                default = (import ./. {}).distribution.direnv-nix-lorelei;
                description = ''
                    The <literal>direnv-nix-lorelei</literal> package to use.
                '';
            };
        };
    };

    config = mkIf cfg.enable {
        xdg.configFile."direnv/lib/nix-lorelei.sh".source =
            "${cfg.package}/share/direnv-nix-lorelei/nix-lorelei.bash";
    };
}
