setup_file()
{
    local testhome
    testhome="$(readlink --canonicalize "$BATS_RUN_TMPDIR/testhome")"

    export HOME="$testhome"
    export XDG_CONFIG_HOME="$testhome/.config"
    export XDG_DATA_HOME="$testhome/.local/share"
    export SRC="$testhome/src"

    local lib="$XDG_CONFIG_HOME/direnv/lib"

    mkdir --parents "$lib" "$XDG_DATA_HOME" "$SRC"
    cp "$LORELEI/share/direnv-nix-lorelei/nix-lorelei.bash" "$lib/nix-lorelei.sh"
    cp "$SHELL_NIX" "$SRC/shell.nix"
    echo "use_nix_gcrooted -a" > "$SRC/.envrc"

    direnv allow "$SRC"
}

@test "Lorelei PATH augmented from build inputs" {
    run dash -c 'direnv exec "$SRC" hello -g "_hello there_" 2>&1 | tail -1'
    [ "$status" -eq 0 ]
    [ "$output" = "_hello there_" ]
}

@test "Lorelei gets other environment variables too" {
    run dash -c 'direnv exec "$SRC" dash -c '"'"' echo "$DIRENV_NIX_LORELEI" '"'"' 2>&1 | tail -1'
    [ "$status" -eq 0 ]
    [ "$output" = "direnv-nix-lorelei-testcase" ]
}

@test "Lorelei watches .envrc" {
    run grep .envrc "$SRC/.direnv/hashes"
    [ "$status" -eq 0 ]
}

@test "Lorelei watches shell.nix" {
    run grep "$SRC/shell.nix" "$SRC/.direnv/hashes"
    [ "$status" -eq 0 ]
}
