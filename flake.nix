{
  description = "Provides a development shell for bvnierop.github.io";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
          pkgs = import nixpkgs {
          inherit system;
          };

          siteEmacs =
            (pkgs.emacsPackagesFor pkgs.emacs).emacsWithPackages (epkgs: with epkgs; [
              htmlize
              dash
              s
              fsharp-mode
          ]);

          site-emacs = pkgs.writeShellApplication {
            name = "site-emacs";
            runtimeInputs = [ siteEmacs ];
            text = ''exec emacs "$@"'';
          };
        in
        with pkgs; {
          devShells.default = mkShell {
            buildInputs = [
              site-emacs
              python3
            ];
          };
        }
      );
}
