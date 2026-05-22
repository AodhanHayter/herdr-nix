{
  description = "Nix package for herdr - agent multiplexer that lives in your terminal";

  nixConfig = {
    extra-substituters = [ "https://herdr-nix.cachix.org" ];
    extra-trusted-public-keys = [ "herdr-nix.cachix.org-1:+AT7TY8E6j/Pe9lB8Vjmp15Y4RPb8YtOnOwr/fboDS8=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        herdr = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.herdr;
          herdr = pkgs.herdr;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.herdr}/bin/herdr";
          };
          herdr = {
            type = "app";
            program = "${pkgs.herdr}/bin/herdr";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch-git
            cachix
            jq
          ];
        };
      }) // {
        overlays.default = overlay;
      };
}
