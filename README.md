# Detection Simulator

`TODO: ADD TEXT HERE`

## Nix

A nix flake has been provided for a development environment. If you have Nix installed and have flakes setup and available, run `nix develop` and it will open a shell with the correct version of godot. If you are not using NixOS but only the package manager, you may need to look at the [next section](#using-nix-on-non-nixos-hosts).

A script will be available called `godot` that will launch godot with the project.

### Using Nix on non NixOS hosts

Godot requires OpenGL which has issues running on non NixOS Linux hosts. If using the Nix package manager on such a system, use the `.#nonnix` devshell with the `--impure` flag.

```bash
nix develop --impure .#nonnix
```
