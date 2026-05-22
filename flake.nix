{
  description = "Nix package for herdr - agent multiplexer that lives in your terminal";

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
