# lib/plugins/default.nix
#
# Composes all SourceMod plugins into a single derivation via symlinkJoin.
# The resulting output has the standard $out/addons/sourcemod/ directory
# layout and can be merged directly into a TF2 server tree.
{ pkgs, helpers }:

let
  plugins = {
    # --- logs / stats / demos ---
    logstf = import ./logstf.nix { inherit pkgs helpers; };
    demostf = import ./demostf.nix { inherit pkgs helpers; };
    supstats2 = import ./supstats2.nix { inherit pkgs helpers; };
    medicstats = import ./medicstats.nix { inherit pkgs helpers; };
    recordstv = import ./recordstv.nix { inherit pkgs helpers; };

    # --- gameplay ---
    p4sstime = import ./p4sstime.nix { inherit pkgs helpers; };
    soap = import ./soap.nix { inherit pkgs helpers; };
    pause = import ./pause.nix { inherit pkgs helpers; };
    afk = import ./afk.nix { inherit pkgs helpers; };
    classwarning = import ./classwarning.nix { inherit pkgs helpers; };
    restorescore = import ./restorescore.nix { inherit pkgs helpers; };

    # --- server management ---
    mapdownloader = import ./mapdownloader.nix { inherit pkgs helpers; };
    rgl-server-resources = import ./rgl-server-resources.nix { inherit pkgs helpers; };

    # --- extensions (native .so) ---
    neocurl = import ./neocurl.nix { inherit pkgs helpers; };
    steamworks = import ./steamworks.nix { inherit pkgs helpers; };

    # --- auto-update ---
    auto-steam-update = import ./auto-steam-update.nix { inherit pkgs helpers; };

    # --- blocked downloads (placeholder hashes, see TODO comments) ---
    # updater = import ./updater.nix { inherit pkgs helpers; };
    # update-check = import ./update-check.nix { inherit pkgs helpers; };
  };
in
pkgs.symlinkJoin {
  name = "tf2-sourcemod-plugins";
  paths = builtins.attrValues plugins;
}
