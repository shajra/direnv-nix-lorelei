{ bats
, coreutils
, dash
, direnv
, direnv-nix-lorelei
, gnugrep
, ncurses
, nix-project-lib
, path
}:

let
    progName = "direnv-nix-lorelei-test";
    meta.description = "Test of Lorelei";
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


. "${nix-project-lib.common}/share/nix-project/common.bash"


NIX_EXE="$(command -v nix || true)"


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
        NIX_PATH="nixpkgs=${path}" \
        SHELL_NIX="${./shell.nix}" \
        LORELEI="${direnv-nix-lorelei}" \
        PATH="$(path_for "$NIX_EXE"):$PATH" \
        bats "${./test.bats}"
}


main "$@"
''
