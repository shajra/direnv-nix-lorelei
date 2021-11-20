inputs: withSystem:
final: prev:

let

    system = prev.stdenv.hostPlatform.system;

    patchLorri = patches: {applyPatches, lorri-src-upstream}:
        applyPatches {
            name = "lorri-stock";
            src = lorri-src-upstream;
            inherit patches;
        };

in withSystem system ({ inputs', ... }: {

    nix-project-lib = inputs'.nix-project.legacyPackages.lib.scripts;

    org2gfm = inputs'.nix-project.packages.org2gfm;

    lorri-src-upstream = inputs.lorri;

    lorri-src-stock = final.callPackage
        (patchLorri [./env_name_cleanup.patch]) {};

    lorri-src-notrace = final.callPackage
        (patchLorri [
            ./remove_trace.patch
            ./env_name_cleanup.patch
        ]) {};

    lorri-runtime = final.callPackage ({callPackage, lorri-src-stock}:
        callPackage (import "${lorri-src-stock}/nix/runtime.nix") {}
    ) {};

    lorri-eval-stock = final.callPackage ({lorri-runtime, lorri-src-stock}:
        {src}: (import "${lorri-src-stock}/src/logged-evaluation.nix") {
            inherit src;
            runTimeClosure = lorri-runtime;
        }
    ) {};

    lorri-eval-notrace = final.callPackage ({lorri-runtime, lorri-src-notrace}:
        {src}: (import "${lorri-src-notrace}/src/logged-evaluation.nix") {
            inherit src;
            runTimeClosure = lorri-runtime;
        }
    ) {};

    lorri-envrc = final.callPackage ({lorri-src-stock}:
        "${lorri-src-stock}/src/ops/direnv/envrc.bash"
    ) {};

    lorelei = final.callPackage ./lorelei.nix {};

    lorelei-home = ./home.nix;

    lorelei-test = final.callPackage ./test {};

})
