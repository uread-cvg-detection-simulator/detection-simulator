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

				godot_export_templates = import ./godot_export_templates.nix { inherit pkgs; godot_version = pkgs.godot_4.version; };

				nix-shell-script = pkgs.writeShellScriptBin "godot" ''
					#!/bin/bash
					$GODOT_BIN --path $PROJECT_NAME -e
				'';

				godot-build-windows = pkgs.writeShellScriptBin "godot-build-windows" ''
					#!/bin/bash
					BUILD_PATH=build/windows
					mkdir -p $BUILD_PATH
					$GODOT_BIN --path $PROJECT_NAME --headless --export-release "Windows Desktop" ../$BUILD_PATH/$PROJECT_NAME.exe
				'';

				godot-build-linux = pkgs.writeShellScriptBin "godot-build-linux" ''
					#!/bin/bash
					BUILD_PATH=build/linux
					mkdir -p $BUILD_PATH
					$GODOT_BIN --path $PROJECT_NAME --headless --export-release "Linux/X11" ../$BUILD_PATH/$PROJECT_NAME.x86_64
				'';

				godot-build-macos = pkgs.writeShellScriptBin "godot-build-macos" ''
					#!/bin/bash
					BUILD_PATH=build/macos
					mkdir -p $BUILD_PATH
					$GODOT_BIN --path $PROJECT_NAME --headless --export-release "macOS" ../$BUILD_PATH/$PROJECT_NAME.zip
				'';

				godot-build-html5 = pkgs.writeShellScriptBin "godot-build-html5" ''
					#!/bin/bash
					BUILD_PATH=build/html5
					mkdir -p $BUILD_PATH
					$GODOT_BIN --path $PROJECT_NAME --headless --export-release "Web" ../$BUILD_PATH/index.html
				'';

				godot-build-all = pkgs.writeShellScriptBin "godot-build-all" ''
					#!/bin/bash
					${godot-build-windows}/bin/godot-build-windows
					${godot-build-linux}/bin/godot-build-linux
					${godot-build-macos}/bin/godot-build-macos
					${godot-build-html5}/bin/godot-build-html5
				'';

				godot-run-tests = pkgs.writeShellScriptBin "godot-run-tests" ''
					#!/bin/bash
					cd $PROJECT_NAME
					./addons/gdUnit4/runtest.sh -a test -c
				'';

				all-scripts = [ nix-shell-script godot-build-windows godot-build-linux godot-build-macos godot-build-html5 godot-build-all godot-run-tests];

				project_name = "detection-simulator";
			in
			{
				devShells = {
					default = pkgs.mkShell {
						packages = dev-package-list ++ all-scripts ++ [ godot_export_templates ];
						GODOT_RAW_BIN = "${pkgs.godot_4}/bin/godot4";
						GODOT_BIN = "${pkgs.godot_4}/bin/godot4";

						shellHook = ''
							set -a; source .env; set +a;

							# Link export templates if not already done ~/.local/share/godot/export_templates/VERSION.stable (update if symlink is to incorrect location)
							if [ ! -d ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable ]; then
								mkdir -p ~/.local/share/godot/export_templates
								ln -s ${godot_export_templates}/templates ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable
							elif [ "$(readlink ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable)" != "${godot_export_templates}/templates" ]; then
								rm -r ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable
								ln -s ${godot_export_templates}/templates ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable
							fi
						'';
					};

					nonnix = pkgs.mkShell {
						packages = dev-package-list ++ [ pkgs.nixgl.auto.nixGLDefault ] ++ all-scripts;
						GODOT_RAW_BIN = "${pkgs.godot_4}/bin/godot4";
						GODOT_BIN = "nixGL ${pkgs.godot_4}/bin/godot4";

						shellHook = ''
							set -a; source .env; set +a;

							# Link export templates if not already done ~/.local/share/godot/export_templates/VERSION.stable (update if symlink is to incorrect location)
							if [ ! -d ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable ]; then
								mkdir -p ~/.local/share/godot/export_templates
								ln -s ${godot_export_templates}/templates ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable
							elif [ "$(readlink ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable)" != "${godot_export_templates}/templates" ]; then
								rm -r ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable
								ln -s ${godot_export_templates}/templates ~/.local/share/godot/export_templates/${godot_export_templates.version}.stable
							fi
						'';
					};
				};
			}
		);

}
