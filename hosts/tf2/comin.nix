# hosts/tf2/comin.nix
#
# GitOps self-deployment via comin.  The server polls the pugs-tf
# GitHub repo and automatically rebuilds when commits land on main.
#
# Two branch slots are configured:
#   main        -> "switch" operation (persists across reboot)
#   testing-tf2 -> "test"   operation (reverts on reboot)
#
# After every successful deployment, a post-deploy script sets the
# pending-restart flag on every TF2 server via the wrapper management
# API.  The existing restart-check timers (tf2-server module) will
# then gracefully restart each server once it empties out.
{ config, lib, pkgs, ... }:

let
  # All enabled TF2 server instances (resolved at NixOS eval time).
  enabledServers = lib.filterAttrs (_: srv: srv.enable) config.services.tf2Server;

  # Port used by Miss Pauling's HTTP API.
  mpPort = toString config.services.missPauling.port;

  # Build the post-deploy script at eval time so all paths and server
  # names are baked in from the Nix store.
  postDeploy = pkgs.writeShellScript "comin-post-deploy" ''
    echo "comin: deployment finished — commit $COMIN_GIT_SHA (status: $COMIN_STATUS)"

    if [ "$COMIN_STATUS" != "success" ]; then
      echo "comin: deployment was not successful, skipping restart signals"
      exit 0
    fi

    MP_URL="http://127.0.0.1:${mpPort}"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: srv: ''
      echo "comin: setting pending restart for ${name}"
      ${pkgs.curl}/bin/curl -sf -X POST \
        "http://127.0.0.1:${toString srv.managementPort}/pending-restart" || \
        echo "comin: warning — could not reach ${name} wrapper (may not be running yet)"
    '') enabledServers)}
  '';

in
{
  services.comin = {
    enable = true;

    remotes = [{
      name = "origin";
      url = "https://github.com/GoodGuyGroves/pugs-tf.git";

      branches.main.name = "main";

      # Push to "testing-tf2" for temporary deploys that revert on reboot.
      branches.testing.name = "testing-tf2";

      poller.period = 60;

      # Repo is public — no auth needed.  Uncomment if it ever goes private:
      # auth.access_token_path = config.sops.secrets."github_access_token".path;
    }];

    postDeploymentCommand = postDeploy;
  };
}
