{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    # The guardrail workflow invokes the Bats TDD-order wrapper.  Pin a
    # standard revision that exports that wrapper; the older transitive pin
    # in nixpkgs-lock does not, causing CI's final command to exit 127.
    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    nix-lefthook.url = "github:pr0d1r2/nix-lefthook";
  };

  outputs = inputs: import ./flake-outputs inputs;
}
