{ bats
, coreutils
, dash
, direnv
, gnugrep
, lorelei
, ncurses
, nix-project-lib
, path
, substituteAll
}:

let
    progName = "lorelei-test";
    meta.description = "Test of Lorelei";
    shellNix = substituteAll {
        src = ./shell.nix.template;
        nixpkgs = path;
    };
in

nix-project-lib.writeShellCheckedExe progName
{
    inherit meta;
    path = [
        bats
        coreutils
        dash
        direnv
        gnugrep
        ncurses  # DESIGN: for fancy Bats output
    ];
}
''
set -eu
set -o pipefail


. "${nix-project-lib.scriptCommon}/share/nix-project/common.bash"


NIX_EXE="$(command -v nix || echo /run/current-system/sw/bin/nix)"


print_usage()
{
    cat - <<EOF
USAGE: ${progName} [OPTION]...

DESCRIPTION:

    Test of Lorelei.  Fails if exits non-zero.

OPTIONS:

    -h --help      print this help message
    -N --nix PATH  filepath of 'nix' executable to use

    '${progName}' pins all dependencies except for Nix itself,
     which it finds on the path if possible.  Otherwise set
     '--nix'.

EOF
}

main()
{
    while ! [ "''${1:-}" = "" ]
    do
        case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -N|--nix)
            NIX_EXE="''${2:-}"
            if [ -z "$NIX_EXE" ]
            then die "$1 requires argument"
            fi
            shift
            ;;
        *)
            die "unrecognized argument: $1"
            ;;
        esac
        shift
    done
    run_test
}

run_test()
{
    env --ignore-environment \
        TERM=linux \
        SHELL_NIX="${shellNix}" \
        LORELEI="${lorelei}" \
        PATH="$(path_for "$NIX_EXE"):$PATH" \
        bats "${./test.bats}"
}


main "$@"
''
