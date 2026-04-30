{
  description = "pugs-tf — NixOS monorepo for the 4v4 PASS Time Europe TF2 community";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Python packaging
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };

    # Container orchestration — Podman quadlets declared in Nix
    quadlet-nix = {
      url = "github:SEIAROTg/quadlet-nix";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GitOps — automatic pull-and-apply for NixOS
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OCI image builder (no Docker daemon needed)
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , uv2nix
    , pyproject-nix
    , pyproject-build-systems
    , quadlet-nix
    , sops-nix
    , comin
    , nix2container
    , ...
    }:
    let
      # Systems we care about — the TF2 server is x86_64-linux,
      # but devShells should work on macOS too.
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Helper: apply a function to each supported system.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Convenience: pkgs set per system.
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # ---------------------------------------------------------------
      # NixOS machine configurations
      # ---------------------------------------------------------------
      nixosConfigurations.tf2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          # External modules
          quadlet-nix.nixosModules.quadlet
          sops-nix.nixosModules.sops
          comin.nixosModules.comin

          # Host-specific config
          ./hosts/tf2

          # Our own modules
          ./modules/tf2-server.nix
          ./modules/miss-pauling.nix
        ];
      };

      # ---------------------------------------------------------------
      # Packages — will hold miss-pauling, tf2-server-wrapper, etc.
      # ---------------------------------------------------------------
      packages.x86_64-linux = {
        configs = import ./lib/configs { pkgs = pkgsFor "x86_64-linux"; };

        # Populated in later issues:
        # miss-pauling       = ...;
        # tf2-server-wrapper = ...;
        # plugins            = ...;
      };

      # ---------------------------------------------------------------
      # Dev shells
      # ---------------------------------------------------------------
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            name = "pugs-tf-dev";
            packages = with pkgs; [
              # Python
              python312
              uv

              # Nix tooling
              nil           # Nix LSP
              nixpkgs-fmt   # formatter

              # General
              git
              jq
            ];

            shellHook = ''
              echo "pugs-tf dev shell loaded"
            '';
          };
        }
      );
    };
}
