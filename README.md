# UREAD Detection Simulator

The UREAD Detection Simulator is a tool for simulating the detection and tracking of objects in a top-down 2D environment. It exports data into a json format that contains x/y co-ordinates and timestamps of the relevant objects. This data can be used to test and validate algorithms for object detection and tracking.

The simulator was originally developed on the EU Horizon project [EURMARS](https://eurmars-project.eu/).

## Features

- Configurable Agents:
  - Speed and acceleration.
  - Link to other agents' waypoints to stop and wait until every one is ready.
  - Wait for a specified amount of time.

- Vehicle Interactions:
  - Person agents can enter and exit vehicle type agents.

- Dynamic event system:
  - Automated events generated when entering/exiting vehicles.
  - Manual events can be setup to trigger with numerous conditions across multiple agents and waypoints.

- Sensors:
  - Sensors with a configurable field of view and range
  - On export, will only produce detection data for agents that are within the sensor's field of view and range.

- Background image with configurable size and scale.

- Exporting:
  - Exports to a set of json files for each agent and sensor.
  - Scripts to be made available to convert the exported co-ordinates into longitude and latitude.

## Available Platforms

The build system produces for Windows, Linux and MacOS.

The MacOS build is not produced on an Apple machine and without a code signing certificate. It should be runnable if you override the security settings in System Preferences. If you are concerned, you can download the source code and build yourself.

## Development Environment

A nix flake has been provided for a development environment. If you have Nix installed and have flakes setup and available, run `nix develop` and it will open a shell with the correct version of godot. If you are not using NixOS but only the package manager, you may need to look at the [next section](#using-nix-on-non-nixos-hosts).

A script called `godot-pr` that will launch godot with the project.

Alternatively, you can use the same version of Godot that is used in the project (4.4 at time of writing).

### Using Nix on non NixOS hosts

Godot requires OpenGL which has issues running on non NixOS Linux hosts. If using the Nix package manager on such a system, use the `.#nonnix` devshell with the `--impure` flag.

```bash
nix develop --impure .#nonnix
```

## Contributions

All contributions should be made as a PR to the master branch.
