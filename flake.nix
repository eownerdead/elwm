{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        formatter = pkgs.nixfmt;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            editorconfig-checker
            nixfmt
            statix
	    wayfire
          ];
          # WLR_BACKENDS = "x11";
          WAYFIRE_CONFIG_FILE = ./wayfire.ini;
        };
      });
}
