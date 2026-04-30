# lib/helpers.nix
#
# Shared helper functions for the pugs-tf monorepo.
#
# Provides fetchSourceModPlugin* helpers that produce derivations with the
# standard SourceMod directory layout under $out/addons/sourcemod/.
{ pkgs }:

{
  # ---------------------------------------------------------------------------
  # fetchSourceModPluginZip
  # ---------------------------------------------------------------------------
  # Fetch a SourceMod plugin distributed as a zip archive.
  #
  # The zip is expected to contain SourceMod sub-directories at its root
  # (e.g. plugins/, gamedata/, translations/, configs/, extensions/).
  # The derivation copies these into $out/addons/sourcemod/ so that the
  # result can be merged directly into a TF2 server tree.
  #
  # Extra arguments (passthru, meta, curlOptsList, …) are forwarded to
  # fetchzip.
  fetchSourceModPluginZip =
    {
      pname,
      version,
      url,
      hash,
      # SourceMod sub-directories to copy from the archive.  Anything else
      # in the archive is silently skipped.
      smDirs ? [
        "plugins"
        "translations"
        "gamedata"
        "configs"
        "extensions"
        "scripting"
      ],
      meta ? { },
      ...
    }@args:
    let
      extra = builtins.removeAttrs args [
        "pname"
        "version"
        "smDirs"
        "meta"
      ];
      src = pkgs.fetchzip (
        {
          inherit url hash;
          stripRoot = false;
          name = "${pname}-${version}-source";
        }
        // (builtins.removeAttrs extra [ "url" "hash" ])
      );
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      dontUnpack = true;

      installPhase =
        let
          copyCommands = builtins.concatStringsSep "\n" (
            map (dir: ''
              if [ -d "${src}/${dir}" ]; then
                cp -r "${src}/${dir}" "$out/addons/sourcemod/${dir}"
              fi
            '') smDirs
          );
        in
        ''
          runHook preInstall

          mkdir -p "$out/addons/sourcemod"
          ${copyCommands}

          runHook postInstall
        '';

      meta = {
        platforms = pkgs.lib.platforms.linux;
      } // meta;
    };

  # ---------------------------------------------------------------------------
  # fetchSourceModPluginSmx
  # ---------------------------------------------------------------------------
  # Fetch a single pre-compiled .smx plugin file.
  #
  # Produces $out/addons/sourcemod/plugins/<pname>.smx.
  fetchSourceModPluginSmx =
    {
      pname,
      version,
      url,
      hash,
      # Override the output filename (without .smx extension).
      # Defaults to pname.
      pluginName ? pname,
      meta ? { },
      ...
    }@args:
    let
      extra = builtins.removeAttrs args [
        "pname"
        "version"
        "pluginName"
        "meta"
      ];
      src = pkgs.fetchurl (
        {
          inherit url hash;
          name = "${pluginName}.smx";
        }
        // (builtins.removeAttrs extra [ "url" "hash" ])
      );
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      dontUnpack = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/addons/sourcemod/plugins"
        cp "${src}" "$out/addons/sourcemod/plugins/${pluginName}.smx"

        runHook postInstall
      '';

      meta = {
        platforms = pkgs.lib.platforms.linux;
      } // meta;
    };
}
