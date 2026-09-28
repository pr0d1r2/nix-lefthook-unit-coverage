{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    set-and-setting.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };

  outputs =
    inputs:
    (
      consumer:
      consumer
      // {
        devShells = builtins.mapAttrs (
          _system: shells:
          builtins.mapAttrs (
            _name: shell:
            shell.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                consumer.packages.${_system}.default
              ];
            })
          ) shells
        ) consumer.devShells;
      }
    )
      (
        inputs.set-and-setting.lib.mkConsumerFlake {
          inherit (inputs) self nixpkgs set-and-setting;
          fragments = [
            "base"
            "actions"
            "nix"
            "shell"
            "ascii"
            "bats"
            "markdown"
            "yaml"
            "toml"
          ];
          src = ./.;
          extraPackages = pkgs: {
            default = pkgs.writeShellApplication {
              name = "lefthook-unit-coverage";
              runtimeInputs = with pkgs; [
                git
                taplo
                coreutils
                findutils
              ];
              text = builtins.readFile ./lefthook-unit-coverage.sh;
            };
          };
        }
      );
}
