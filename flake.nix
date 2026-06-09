{
  description = "Lefthook-compatible test coverage check — multi-language via TOML config";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    nix-lefthook-deadnix-src = {
      url = "github:pr0d1r2/nix-lefthook-deadnix";
      flake = false;
    };
    nix-lefthook-editorconfig-checker-src = {
      url = "github:pr0d1r2/nix-lefthook-editorconfig-checker";
      flake = false;
    };
    nix-lefthook-file-size-check-src = {
      url = "github:pr0d1r2/nix-lefthook-file-size-check";
      flake = false;
    };
    nix-lefthook-git-conflict-markers-src = {
      url = "github:pr0d1r2/nix-lefthook-git-conflict-markers";
      flake = false;
    };
    nix-lefthook-git-no-local-paths-src = {
      url = "github:pr0d1r2/nix-lefthook-git-no-local-paths";
      flake = false;
    };
    nix-lefthook-missing-final-newline-src = {
      url = "github:pr0d1r2/nix-lefthook-missing-final-newline";
      flake = false;
    };
    nix-lefthook-nix-no-embedded-shell-src = {
      url = "github:pr0d1r2/nix-lefthook-nix-no-embedded-shell";
      flake = false;
    };
    nix-lefthook-nixfmt-src = {
      url = "github:pr0d1r2/nix-lefthook-nixfmt";
      flake = false;
    };
    nix-lefthook-shellcheck-src = {
      url = "github:pr0d1r2/nix-lefthook-shellcheck";
      flake = false;
    };
    nix-lefthook-shfmt-src = {
      url = "github:pr0d1r2/nix-lefthook-shfmt";
      flake = false;
    };
    nix-lefthook-statix-src = {
      url = "github:pr0d1r2/nix-lefthook-statix";
      flake = false;
    };
    nix-lefthook-trailing-whitespace-src = {
      url = "github:pr0d1r2/nix-lefthook-trailing-whitespace";
      flake = false;
    };
    nix-lefthook-typos-src = {
      url = "github:pr0d1r2/nix-lefthook-typos";
      flake = false;
    };
    nix-lefthook-yamllint-src = {
      url = "github:pr0d1r2/nix-lefthook-yamllint";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-lefthook-deadnix-src,
      nix-lefthook-editorconfig-checker-src,
      nix-lefthook-file-size-check-src,
      nix-lefthook-git-conflict-markers-src,
      nix-lefthook-git-no-local-paths-src,
      nix-lefthook-missing-final-newline-src,
      nix-lefthook-nix-no-embedded-shell-src,
      nix-lefthook-nixfmt-src,
      nix-lefthook-shellcheck-src,
      nix-lefthook-shfmt-src,
      nix-lefthook-statix-src,
      nix-lefthook-trailing-whitespace-src,
      nix-lefthook-typos-src,
      nix-lefthook-yamllint-src,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});

      lefthookWrappersFor =
        pkgs:
        let
          wrap =
            name: src: extra:
            pkgs.writeShellApplication (
              {
                inherit name;
                text = builtins.readFile "${src}/${name}.sh";
              }
              // extra
            );
        in
        [
          (wrap "lefthook-deadnix" nix-lefthook-deadnix-src {
            runtimeInputs = [ pkgs.deadnix ];
          })
          (wrap "lefthook-editorconfig-checker" nix-lefthook-editorconfig-checker-src {
            runtimeInputs = [ pkgs.editorconfig-checker ];
          })
          (wrap "get-file-size-limit" nix-lefthook-file-size-check-src {
            runtimeInputs = [
              pkgs.gawk
              pkgs.gnugrep
            ];
          })
          (pkgs.writeShellApplication {
            name = "lefthook-file-size-check";
            runtimeInputs = [
              pkgs.gawk
              pkgs.gnugrep
              pkgs.coreutils
              (wrap "get-file-size-limit" nix-lefthook-file-size-check-src {
                runtimeInputs = [
                  pkgs.gawk
                  pkgs.gnugrep
                ];
              })
            ];
            text = builtins.readFile "${nix-lefthook-file-size-check-src}/lefthook-file-size-check.sh";
          })
          (wrap "lefthook-git-conflict-markers" nix-lefthook-git-conflict-markers-src {
            runtimeInputs = [ pkgs.gnugrep ];
          })
          (wrap "lefthook-git-no-local-paths" nix-lefthook-git-no-local-paths-src {
            runtimeInputs = [ pkgs.gnugrep ];
          })
          (wrap "lefthook-missing-final-newline" nix-lefthook-missing-final-newline-src { })
          (pkgs.writeShellApplication {
            name = "lefthook-nix-no-embedded-shell";
            text = ''
              SCANNER="${nix-lefthook-nix-no-embedded-shell-src}/scan-nix-no-embedded-shell.sh"
            ''
            + builtins.readFile "${nix-lefthook-nix-no-embedded-shell-src}/lefthook-nix-no-embedded-shell.sh";
          })
          (wrap "lefthook-nixfmt" nix-lefthook-nixfmt-src {
            runtimeInputs = [ pkgs.nixfmt ];
          })
          (wrap "lefthook-shellcheck" nix-lefthook-shellcheck-src {
            runtimeInputs = [ pkgs.shellcheck ];
          })
          (wrap "lefthook-shfmt" nix-lefthook-shfmt-src {
            runtimeInputs = [ pkgs.shfmt ];
          })
          (wrap "lefthook-statix" nix-lefthook-statix-src {
            runtimeInputs = [ pkgs.statix ];
          })
          (wrap "lefthook-trailing-whitespace" nix-lefthook-trailing-whitespace-src {
            runtimeInputs = [ pkgs.gnugrep ];
          })
          (wrap "lefthook-typos" nix-lefthook-typos-src {
            runtimeInputs = [ pkgs.typos ];
          })
          (wrap "lefthook-yamllint" nix-lefthook-yamllint-src {
            runtimeInputs = [ pkgs.yamllint ];
          })
        ];

      batsWithLibsFor =
        pkgs:
        pkgs.bats.withLibraries (p: [
          p.bats-support
          p.bats-assert
          p.bats-file
        ]);
    in
    {
      packages = forAllSystems (pkgs: {
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
      });

      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          batsWithLibs = batsWithLibsFor pkgs;
          ciCommon = [
            self.packages.${system}.default
            batsWithLibs
            pkgs.bats
            pkgs.coreutils
            pkgs.git
            pkgs.lefthook
            pkgs.nix
            pkgs.parallel
            pkgs.statix
          ]
          ++ (lefthookWrappersFor pkgs);
        in
        {
          ci = pkgs.mkShell {
            packages = ciCommon;
            BATS_LIB_PATH = "${batsWithLibs}/share/bats";
          };
          default = pkgs.mkShell {
            packages = ciCommon;
            shellHook = builtins.replaceStrings [ "@BATS_LIB_PATH@" ] [ "${batsWithLibs}" ] (
              builtins.readFile ./dev.sh
            );
          };
        }
      );
    };
}
