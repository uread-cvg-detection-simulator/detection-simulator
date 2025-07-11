## 1.0.9

## 1.0.8

## 1.0.7

## 1.0.6

- Fix the zenodo doi missing from the build.

## 1.0.5

## 1.0.4

- Another potential fix for zenodo publishing issues.

## 1.0.3

- Potential fix for zenodo publishing issues.

## 1.0.2

- Added .zenodo.json file for a better looking zenodo page
- Changed zenodo publishing method (use github action instead of auto sync)
- Other development only changes

## 1.0.1

Some fixes to the build environment and version bumper script. No functional changes to the software.

## 1.0.0

Initial release. Here is a rough summary of the features:

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
