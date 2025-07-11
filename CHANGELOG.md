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
