{ pkgs, godot_version }:
let
	godot_export_hashes = version: {
		"4.1.1" = "sha256-22BPoqPmcako7EmBmyJAet9chSKQZ4RXUktendyK2fU=";
	}.${version} or (
		pkgs.lib.warn "No hash for Godot version ${version} found" pkgs.lib.fakeHash
	);

	godot_export_templates_src = pkgs.fetchurl {
		url = "https://github.com/godotengine/godot/releases/download/${godot_version}-stable/Godot_v${godot_version}-stable_export_templates.tpz";
		hash = godot_export_hashes godot_version;
	};


	godot_export_templates = pkgs.stdenv.mkDerivation {
		name = "godot_export_templates-${godot_version}";
		src = godot_export_templates_src;
		phases = [ "unpackPhase" ];

		buildInputs = [ pkgs.unzip ];

		unpackPhase = ''
			mkdir -p $out
			unzip -d $out $src
		'';
	};
in
godot_export_templates
