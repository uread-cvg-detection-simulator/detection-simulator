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

				godot-build-windows = pkgs.writeShellScriptBin "godot-build-windows" ''
					#!/bin/bash
					BUILD_PATH=build/windows
					mkdir -p $BUILD_PATH
					$GODOT_CMD --path $PROJECT_NAME --headless --export-release "Windows Desktop" ../$BUILD_PATH/$PROJECT_NAME.exe
				'';

				godot-build-linux = pkgs.writeShellScriptBin "godot-build-linux" ''
					#!/bin/bash
					BUILD_PATH=build/linux
					mkdir -p $BUILD_PATH
					$GODOT_CMD --path $PROJECT_NAME --headless --export-release "Linux/X11" ../$BUILD_PATH/$PROJECT_NAME.x86_64
				'';

				godot-build-macos = pkgs.writeShellScriptBin "godot-build-macos" ''
					#!/bin/bash
					BUILD_PATH=build/macos
					mkdir -p $BUILD_PATH
					$GODOT_CMD --path $PROJECT_NAME --headless --export-release "macOS" ../$BUILD_PATH/$PROJECT_NAME.zip
				'';

				godot-build-html5 = pkgs.writeShellScriptBin "godot-build-html5" ''
					#!/bin/bash
					BUILD_PATH=build/html5
					mkdir -p $BUILD_PATH
					$GODOT_CMD --path $PROJECT_NAME --headless --export-release "Web" ../$BUILD_PATH/index.html
				'';

				godot-build-all = pkgs.writeShellScriptBin "godot-build-all" ''
					#!/bin/bash
					${godot-build-windows}/bin/godot-build-windows
					${godot-build-linux}/bin/godot-build-linux
					${godot-build-macos}/bin/godot-build-macos
					${godot-build-html5}/bin/godot-build-html5
				'';

				all-scripts = [ nix-shell-script godot-build-windows godot-build-linux godot-build-macos godot-build-html5 godot-build-all ];

			in
			{
				devShells = {
					default = pkgs.mkShell {
						packages = dev-package-list ++ all-scripts;
						shellHook = ''
							export GODOT_CMD="${pkgs.godot_4}/bin/godot4"
							set -a; source .env; set +a;
						'';
					};

					nonnix = pkgs.mkShell {
						packages = dev-package-list ++ [ pkgs.nixgl.auto.nixGLDefault ] ++ all-scripts;
						shellHook = ''
							export GODOT_CMD="nixGL ${pkgs.godot_4}/bin/godot4"
							set -a; source .env; set +a;
						'';
					};
				};
			}
		);

}
