{ coreutils
, findutils
, gnused
, jq
, lib
, lorri-envrc
, lorri-eval-stock
, lorri-eval-patched
, nix-project-lib
, path
, xxHash
}:

let
    name = "direnv-nix-lorelei";
    meta.description = "Alternative Nix functions for Direnv";
    packagePath = "direnv-nix-lorelei";
    baseName = "nix-lorelei";
    buildSource = lib.sourceFilesBySuffices ./. [
        ".json"
        ".nix"
        ".patch"
    ];

in

nix-project-lib.writeShellCheckedShareLib name packagePath
{
    inherit meta baseName;
}
''
# shellcheck shell=bash

_nixgc_usage()
{
    "${coreutils}/bin/cat" - <<EOF
USAGE: use_nix_gcrooted [OPTION]... [FILE]

DESCRIPTION:

    A replacement for Direnv's use_nix.  This function, will make
    sure calculated Nix expressions are GC rooted with Nix.  By
    default the calculated environment is also cached, which is
    useful for Nix expressions that have costly evaluations.  To
    invalidate the cache, files can be watched either by their
    content hash or their modification time.  You can also delete
    .direnv/delete_to_rebuild to invalidate the cache.

OPTIONS:

    -h --help                print this help message
    -a --auto-watch-content  watch autodetected files for contect
                             changes
    -A --auto-watch-mtime    watch autodetected files for
                             modification times
    -d --auto-watch-deep     deeper searching for -a and -A options
    -w --watch-content PATH  watch a file's content for changes
    -W --watch-mtime PATH    watch a file's modification time
    -C --ignore-cache        recompute new environment every time
    -k --keep-last NUM       protect last N caches from GC
                             (default 5)

EOF
}

use_nix_gcrooted()
{
    if ! [ "''${DIRENV_IN_ENVRC:-}" = "1" ]
    then
        _nixgc_usage
        return 0
    fi

    local ignore_cache="false"
    local watched_by_mtime=()
    local watched_by_hash=(.envrc)
    # DESIGN: auto_watch_none is intentionally discarded
    # shellcheck disable=SC2034
    local auto_watch_none=()
    local auto_watch_mtime=()
    local auto_watch_hash=()
    local auto_watch_eval=patched
    local auto_watch=auto_watch_none
    local shell_file=""
    local keep_last=5

    local env_cache; env_cache="$(direnv_layout_dir)/env"
    local hash_cache; hash_cache="$(direnv_layout_dir)/hashes"
    local build_proof
    build_proof="$(direnv_layout_dir)/delete_to_rebuild"
    "${coreutils}/bin/mkdir" -p "$(direnv_layout_dir)"

    _nixgc_parse_args \
        ignore_cache \
        watched_by_mtime \
        watched_by_hash \
        auto_watch \
        auto_watch_eval \
        shell_file \
        keep_last \
        "$@"

    _nixgc_validate_options "$shell_file" "$keep_last"

    if _nixgc_rebuild_needed \
        "$ignore_cache" \
        "$build_proof" \
        "$hash_cache" \
        watched_by_mtime \
        watched_by_hash
    then
        _nixgc_rebuild \
            "$env_cache" \
            "$shell_file" \
            "$keep_last" \
            "$auto_watch_eval" \
            "$auto_watch"
        _nixgc_record_build_proof "$build_proof" \
            "''${watched_by_mtime[@]}" "''${auto_watch_mtime[@]}"
        _nixgc_record_hashes \
            "''${watched_by_hash[@]}" "''${auto_watch_hash[@]}"
    else
        log_status "using cached environment"
    fi

    _nixgc_import_env "$env_cache"

    while read -r f
    do
        log_status "watching $f"
        watch_file "$f"
    done < <(_nixgc_watched_from_file "$build_proof" "$hash_cache")
}

_nixgc_parse_args()
{
    local -n _ignore_cache="$1"; shift
    local -n _watched_by_mtime="$1"; shift
    local -n _watched_by_hash="$1"; shift
    local -n _auto_watch="$1"; shift
    local -n _auto_watch_eval="$1"; shift
    local -n _shell_file="$1"; shift
    local -n _keep_last="$1"; shift

    local default_shell_file=shell.nix
    if ! [ -f "$default_shell_file" ]
    then default_shell_file=default.nix
    fi

    while ! [ "''${1:-}" = "" ]
    do
        case "$1" in
        -h|--help)
            _nixgc_usage
            exit 0
            ;;
        -a|--auto-watch-content)
            _auto_watch=auto_watch_hash
            ;;
        -A|--auto-watch-mtime)
            _auto_watch=auto_watch_mtime
            ;;
        -C|--ignore_cache)
            # DESIGN: https://github.com/koalaman/shellcheck/issues/817
            # shellcheck disable=SC2034
            _ignore_cache=true
            ;;
        -d|--auto-watch-deep)
            # DESIGN: https://github.com/koalaman/shellcheck/issues/817
            # shellcheck disable=SC2034
            _auto_watch_eval=stock
            ;;
        -k|--keep-last)
            if [ -z "''${2:-}" ]
            then
                _nixgc_fail "$1 requires argument"
            fi
            # DESIGN: https://github.com/koalaman/shellcheck/issues/817
            # shellcheck disable=SC2034
            _keep_last="''${2:-}"
            shift
            ;;
        -w|--watch-content)
            if [ -z "''${2:-}" ]
            then
                _nixgc_fail "$1 requires argument"
            fi
            _watched_by_hash+=("''${2:-}")
            shift
            ;;
        -W|--watch-mtime)
            if [ -z "''${2:-}" ]
            then
                _nixgc_fail "$1 requires argument"
            fi
            _watched_by_mtime+=("''${2:-}")
            shift
            ;;
        *)
            if [ -z "$_shell_file" ]
            then _shell_file="$1"
            else _nixgc_fail "too many positional arguments"
            fi
            ;;
        esac
        shift
    done
    _shell_file="''${_shell_file:-''${default_shell_file}}"
}

_nixgc_validate_options()
{
    local shell_file="$1"
    local keep_last="$2"
    if ! [ -f "$shell_file" ]
    then _nixgc_fail "not found: $shell_file"
    fi
    if ! [ "$keep_last" -gt 0 ]
    then _nixgc_fail "keep last: not integer greater than 0: $keep_last"
    fi
}

_nixgc_rebuild_needed()
{
    local ignore_cache="$1"
    local build_proof="$2"
    local hash_cache="$3"
    # DESIGN: https://github.com/koalaman/shellcheck/issues/2060
    # shellcheck disable=SC2178
    local -n _watched_by_mtime="$4"
    # DESIGN: https://github.com/koalaman/shellcheck/issues/2060
    # shellcheck disable=SC2178
    local -n _watched_by_hash="$5"

    if "$ignore_cache"
    then
        log_status "cache ignored as requested"
        return 0
    fi

    _nixgc_rebuild_needed_mtime "$build_proof" "''${_watched_by_mtime[@]}" \
        || _nixgc_rebuild_needed_hash "$hash_cache" "''${_watched_by_hash[@]}"
}

_nixgc_rebuild_needed_mtime()
{
    local build_proof="$1"; shift
    if ! [ -f "$build_proof" ]
    then
        log_status "initializing cache"
        return 0
    fi
    local from_file=()
    mapfile -t from_file < <("${coreutils}/bin/cat" "$build_proof")
    for f in "$@" "''${from_file[@]}"
    do
        if ! [ -f "$f" ]
        then
             log_status "missing and ignored: $f"
             return 1
        elif [ "$f" -nt "$build_proof" ]
        then
             log_status "cached invalidated by modification: $f"
             return 0
        else
             log_status "not modified: $f"
        fi
    done
    return 1
}

_nixgc_record_build_proof()
{
    local build_proof="$1"
    printf "%s\n" "$@" > "$build_proof"
}

_nixgc_record_hashes()
{
    "${xxHash}/bin/xxhsum" "$@" > "$hash_cache"
}

_nixgc_rebuild_needed_hash()
{
    local hash_cache="$1"; shift
    if ! [ -f "$hash_cache" ]
    then
        log_status "initializing hashes: $hash_cache"
        return 0
    fi
    if ! "${xxHash}/bin/xxhsum" --check "$hash_cache" >/dev/null
    then
        log_status "hash check invalidated cache"
        return 0
    else
        log_status "no watched hashes changed"
        return 1
    fi
}

_nixgc_watched_from_file()
{
    local build_proof="$1"
    local hash_cache="$2"
    "${coreutils}/bin/cat" "$build_proof"
    "${gnused}/bin/sed" -n 's/.*\s\+\(.*\)/\1/p' < "$hash_cache"
}

_nixgc_rebuild()
{
    local env_cache="$1"
    local shell_file=
    shell_file="$("${coreutils}/bin/readlink" -f "$2")"
    local keep_last="$3"
    local auto_watch_eval="$4"
    # DESIGN: https://github.com/koalaman/shellcheck/issues/817
    # shellcheck disable=SC2034
    local -n _auto_watch="$5"

    local cache_root
    cache_root="$("${coreutils}/bin/dirname" "$env_cache")"

    log_status "rebuilding with Nix"
    "${coreutils}/bin/rm" --recursive --force "$env_cache"
    "${coreutils}/bin/mkdir" --parents "$cache_root"

    local store_path=()
    local build_err=()
    _nixgc_build_autowatching \
        "$shell_file" "$auto_watch_eval" store_path _auto_watch build_err
    if [ -z "''${store_path[0]}" ]
    then
        for l in "''${build_err[@]}"
        do log_error "$l"
        done
         _nixgc_fail "ERROR: Nix build failed"
    fi

    local _pwd;
    _pwd="$(pwd)"
    _pwd="$("${coreutils}/bin/readlink" -f "$_pwd")"
    local pwd_hash
    pwd_hash="''${store_path[0]}"
    pwd_hash="''${pwd_hash#/nix/store/}"
    pwd_hash="''${pwd_hash%%-*}"
    local escaped_pwd="''${_pwd/\/}"
    escaped_pwd="''${escaped_pwd//\//:}"

    "${coreutils}/bin/ln" --force --symbolic --no-target-directory \
        "''${store_path[0]}" \
        "$env_cache-$pwd_hash"

    "${coreutils}/bin/ln" --force --symbolic --no-target-directory \
        "$env_cache-$pwd_hash" \
        "$env_cache"

    local gcroot="/nix/var/nix/gcroots/per-user/$USER"
    "${coreutils}/bin/ln" --force --symbolic --no-target-directory \
        "$env_cache-$pwd_hash" \
        "$gcroot/$escaped_pwd:$pwd_hash"

    "${findutils}/bin/find" "$cache_root" \
            -type l -wholename "$env_cache-*" -printf "%T+/%p\n" \
        | "${coreutils}/bin/sort" --reverse \
        | "${coreutils}/bin/tail" --lines=+"$(("$keep_last" + 1))" \
        | {
        while read -r line
        do
            local f="''${line#*/}"
            log_status "allowing GC (keeping last $keep_last): $f"
            "${coreutils}/bin/rm" "$f"
        done
    }

    "${findutils}/bin/find" -L "$gcroot" \
        -type l \
        -name "$escaped_pwd:*" \
        -exec "${coreutils}/bin/rm" {} +
}

_nixgc_build_autowatching()
{
    local shell_file="$1"
    local auto_watch_eval="$2"
    local -n _out="$3"
    local -n _watched="$4"
    local -n _build_err="$5"
    local both=()
    local err=()
    mapfile -t both < <({
        { _nixgc_build "$shell_file" "$auto_watch_eval" \
            | _nixgc_capture o ;
        } 3>&1 1>&2 2>&3 | _nixgc_capture e ;
    } 2>&1)
    # DESIGN: https://github.com/koalaman/shellcheck/issues/817
    # shellcheck disable=SC2034
    mapfile -t _out < <(printf "%s\n" "''${both[@]}" | _nixgc_select_line o)
    # DESIGN: https://github.com/koalaman/shellcheck/issues/817
    # shellcheck disable=SC2034
    mapfile -t err < <(printf "%s\n" "''${both[@]}" | _nixgc_select_line e)
    # DESIGN: https://github.com/koalaman/shellcheck/issues/817
    # shellcheck disable=SC2034
    mapfile -t _watched < <(printf "%s\n" "''${err[@]}" \
        | _nixgc_capture_autowatchable)
    # DESIGN: https://github.com/koalaman/shellcheck/issues/817
    # shellcheck disable=SC2034
    mapfile -t _build_err < <(printf "%s\n" "''${err[@]}" \
        | "${gnused}/bin/sed" -n '/^error:/,$p')
}

_nixgc_build()
{
    local shell_file="$1"
    local auto_watch_eval="$2"
    IN_NIX_SHELL=1 \
        nix-build \
        --show-trace \
        --verbose --verbose \
        --no-out-link \
        --arg src "$shell_file" \
        --expr "((import ${buildSource} {}).build.lorri-eval-$auto_watch_eval)"
}

_nixgc_select_line()
{
    local prefix="$1"
    "${gnused}/bin/sed" -n "s/^$prefix: \(.*\)$/\1/p"
}

_nixgc_capture()
{
    local prefix="$1"
    "${coreutils}/bin/stdbuf" -oL \
        "${gnused}/bin/sed" -n "s/\(.*\)/$prefix: \1/p"
}

_nixgc_capture_autowatchable()
{
    "${gnused}/bin/sed" -n "
        # find paths and substitute the line for them
        s/\(copied source\|evaluating file\|trace: lorri read:\)[^']*'\([^']\+\)'.*/\2/;
        # delete /nix/store paths, lines with no found paths, and empty lines
        /^\(\/nix\/\|[^\/]\|$\)/d;
        # print paths found not in /nix/store
        p
    " | {
        while read -r f
        do
            if [ -d "$f" ]
            then echo "$f/default.nix"
            else echo "$f"
            fi
        done
    } | "${coreutils}/bin/sort" -u
}

_nixgc_import_env()
{
    local EVALUATION_ROOT="$1"
    . "${lorri-envrc}"
}

_nixgc_fail()
{
    log_error "$@"
    exit 1
}
''
