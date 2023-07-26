{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		flake-utils.url = "github:numtide/flake-utils";
		nixGL = {
			url = "github:guibou/nixGL";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { nixpkgs, flake-utils, nixGL, ... } : 
		flake-utils.lib.eachDefaultSystem (system: 
			let
				pkgs = import nixpkgs {
					system = system;
					config = { allowUnfree = true; };
					overlays = [ nixGL.overlay ];
				};

				lib = pkgs.lib;

				dev-package-list = with pkgs; [ godot_4 ];

				nix-shell-script = pkgs.writeShellScriptBin "godot" ''
					#!/bin/bash
					$GODOT_CMD --path $PROJECT_NAME -e
				'';

			in
			{
				devShells = {
					default = pkgs.mkShell {
						packages = dev-package-list ++ [ nix-shell-script ];
						shellHook = ''
							export GODOT_CMD="${pkgs.godot_4}/bin/godot4"
							set -a; source .env; set +a;
						'';
					};

					nonnix = pkgs.mkShell {
						packages = dev-package-list ++ [ pkgs.nixgl.auto.nixGLDefault nix-shell-script ];
						shellHook = ''
							export GODOT_CMD="nixGL ${pkgs.godot_4}/bin/godot4"
							set -a; source .env; set +a;
						'';
					};
				};
			}
		);

}
