{ pkgs, godot_version }:
let
	godot_export_hashes = version: {
		"4.1.1" = "sha256-22BPoqPmcako7EmBmyJAet9chSKQZ4RXUktendyK2fU=";
		"4.1.3" = "sha256-QZBa0/8jLTf1XHHsFZnYM5v+81P2GN5obev4fT0OtHM=";
	}.${version} or (
		pkgs.lib.warn "No hash for Godot version ${version} found" pkgs.lib.fakeHash
	);

	# If 'stable' in godot_version, remove it
	godot_version_mod = pkgs.lib.replaceStrings ["-stable"] [""] godot_version;

	godot_export_templates_src = pkgs.fetchurl {
		url = "https://github.com/godotengine/godot/releases/download/${godot_version_mod}-stable/Godot_v${godot_version_mod}-stable_export_templates.tpz";
		hash = godot_export_hashes godot_version_mod;
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
