#!/usr/bin/env python3

import os
import shlex
import subprocess
import sys
from enum import Enum
from typing import List

import typer
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Get project name from environment
PROJECT_NAME = os.getenv('PROJECT_NAME', 'detection-simulator')

app = typer.Typer()


class BumpType(str, Enum):
	"""
	Enum for the different bump types.
	"""

	MAJOR = "major"
	MINOR = "minor"
	PATCH = "patch"


@app.command()
def bump(bump_type: BumpType, dry_run: bool = False):

	project_file = f"{PROJECT_NAME}/project.godot"

	if not os.path.exists(project_file):
		print(f"ERROR: Could not find {project_file}")
		return 1

	# Get current version from project.godot
	with open(project_file, "r") as f:
		lines = f.readlines()

		for line in lines:
			if "config/version=" in line:
				version = line.split("=")[1].strip()
				version = version.replace("\"", "")
				break
		else:
			# If no version found, assume 0.0.0
			version = "0.0.0"

	# Parse version
	version_parts = version.split(".")
	major = int(version_parts[0])
	minor = int(version_parts[1])
	patch = int(version_parts[2])

	# Bump version
	if bump_type == BumpType.MAJOR:
		major += 1
		minor = 0
		patch = 0
	elif bump_type == BumpType.MINOR:
		minor += 1
		patch = 0
	elif bump_type == BumpType.PATCH:
		patch += 1
	else:
		raise Exception("Unknown bump type")

	# Print version change
	print(f"Bumping version from {version} to {major}.{minor}.{patch}")

	# Update files if not a dry run
	if not dry_run:

		# Check if any unstaged changes
		if subprocess.run(["git", "diff", "--exit-code"]).returncode != 0:
			print("There are unstaged changes. Please commit or stash them before continuing.")
			return None

		# Check if ok to proceed
		if not typer.confirm(f"Are you sure you want to bump version to {major}.{minor}.{patch}?"):
			return None

		print("Starting update...")

		# Start git flow release
		subprocess.run(["git", "flow", "release", "start", f"{major}.{minor}.{patch}"])

		print("Updating files...")

		# Update project.godot
		update_project_godot(project_file, major, minor, patch)

		# Update changelogs
		log_files = ["CHANGELOG.md", "CHANGES.md", "RELEASE_NOTES.md"]

		log_found = update_changelogs(log_files, major, minor, patch)

		if not log_found:
			print(f"No log file found out of [{','.join(log_files)}]. Skipping...")

		# Ask if user wants to edit changelog
		if log_found:
			if typer.confirm("Do you want to edit the changelog before committing?"):
				# Find which changelog file was updated
				changelog_file = None
				for log_file in log_files:
					if os.path.isfile(log_file):
						changelog_file = log_file
						break

				if changelog_file:
					editor = os.environ.get('EDITOR', 'nano')
					print(f"Opening {changelog_file} with {editor}...")
					subprocess.run([editor, changelog_file])

					if typer.confirm("Are you satisfied with the changelog changes?"):
						subprocess.run(["git", "add", changelog_file])
					else:
						print("Changelog changes not staged. You can manually stage them later.")

		# Ask if user wants to commit the changes
		if typer.confirm("Do you want to commit all the version bump changes?"):
			subprocess.run(["git", "commit", "-m", f"Bump version to {major}.{minor}.{patch}"])

			# Ask user if want to finish release
			if typer.confirm("Do you want to finish the release?"):
				run_finish_release(major, minor, patch)
				print("Release finished")
			else:
				print(f"Release branch 'release/{major}.{minor}.{patch}' created with changes committed.")
				print("You can finish the release later with: ./version_bumper.py release")
		else:
			print("Changes staged but not committed.")
			print(f"You are now on release branch 'release/{major}.{minor}.{patch}'.")
			print("You can:")
			print("  - Review staged changes: git status")
			print("  - Commit manually: git commit -m 'Your message'")
			print("  - Continue with: ./version_bumper.py release")
			print("  - Or revert: git flow release delete {major}.{minor}.{patch} -f")

	return 0


def update_project_godot(project_file: str, major: int, minor: int, patch: int):
	"""
	Update version in project.godot file

	:param project_file: Path to project.godot
	:param major: Major version
	:param minor: Minor version
	:param patch: Patch version
	"""

	lines = open(project_file, "r").readlines()

	version_found = False

	with open(project_file, "w") as f:
		for line in lines:
			if "config/version=" in line:
				f.write(f'config/version="{major}.{minor}.{patch}"\n')
				version_found = True
			else:
				f.write(line)

	# If no version line was found, add it after config/name
	if not version_found:
		lines = open(project_file, "r").readlines()

		with open(project_file, "w") as f:
			for line in lines:
				f.write(line)
				if "config/name=" in line:
					f.write(f'config/version="{major}.{minor}.{patch}"\n')

	# Stage project.godot (will be committed later with changelog)
	subprocess.run(["git", "add", project_file])


def update_changelogs(log_files: List[str], major: int, minor: int, patch: int) -> bool:
	"""
	Update changelogs

	:param log_files: List of log files to update
	:param major: Major version
	:param minor: Minor version
	:param patch: Patch version
	:return: True if a log file was found, False otherwise
	"""

	log_found = False

	for log_file in log_files:
		if os.path.isfile(log_file):
			log_found = True

			lines = open(log_file, "r").readlines()

			found_unreleased = False

			# Replace 'Unreleased' with '## {major}.{minor}.{patch}'
			with open(log_file, "w") as f:
				for line in lines:
					if line.startswith("## Unreleased"):
						f.write(f"## {major}.{minor}.{patch}\n")
						found_unreleased = True
					else:
						f.write(line)

			if not found_unreleased:
				print(f"Could not find 'Unreleased' section in {log_file}")
			else:
				print(f"Updated {log_file} with version {major}.{minor}.{patch}")
				# Don't commit here - let user edit first

	return log_found


def run_finish_release(major: int, minor: int, patch: int):
	"""
	Finish the git flow release

	:param major: Major version
	:param minor: Minor version
	:param patch: Patch version
	"""

	# Finish release and push all changes
	subprocess.run(shlex.split(f"git flow release finish {major}.{minor}.{patch} -m \"Bump version to {major}.{minor}.{patch}\" --pushtag --pushproduction --pushdevelop"))

	print("Release finished")


@app.command()
def release():
	project_file = f"{PROJECT_NAME}/project.godot"

	# Parse version from project.godot
	with open(project_file, "r") as f:
		lines = f.readlines()

		for line in lines:
			if "config/version=" in line:
				version = line.split("=")[1].strip()
				version = version.replace("\"", "")
				break
		else:
			raise Exception(f"Could not find version in {project_file}")

	# Parse version
	version_parts = version.split(".")
	major = int(version_parts[0])
	minor = int(version_parts[1])
	patch = int(version_parts[2])

	# Check if on a release branch for this version
	branch_name = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).decode("utf-8").strip()

	if branch_name != f"release/{major}.{minor}.{patch}":
		raise Exception(f"You are not on the release branch for version {major}.{minor}.{patch}")

	# Finish release and push all changes
	run_finish_release(major, minor, patch)

	return 0


@app.command()
def current():
	"""Show current version"""
	project_file = f"{PROJECT_NAME}/project.godot"

	if not os.path.exists(project_file):
		print(f"ERROR: Could not find {project_file}")
		return 1

	with open(project_file, "r") as f:
		lines = f.readlines()

		for line in lines:
			if "config/version=" in line:
				version = line.split("=")[1].strip()
				version = version.replace("\"", "")
				print(f"Current version: {version}")
				return 0
		else:
			print("No version found in project.godot")
			return 1


if __name__ == '__main__':
	sys.exit(app())