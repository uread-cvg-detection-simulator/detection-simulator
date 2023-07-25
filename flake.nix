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

				nonnix-shell-script = pkgs.writeShellScriptBin "godot" ''
					#!/bin/bash
					nixGL ${pkgs.godot_4}/bin/godot4 "$@"
				'';

				nix-shell-script = pkgs.writeShellScriptBin "godot" ''
					#!/bin/bash
					${pkgs.godot_4}/bin/godot4 "$@"
				'';

			in
			{
				devShells = {
					default = pkgs.mkShell {
						packages = dev-package-list ++ [ nix-shell-script ];
					};

					nonnix = pkgs.mkShell {
						packages = dev-package-list ++ [ pkgs.nixgl.auto.nixGLDefault nonnix-shell-script ];
					};
				};
			}
		);

}
