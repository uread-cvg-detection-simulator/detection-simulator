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

		# Check for existing release branches and clean them up
		try:
			branches_output = subprocess.check_output(["git", "branch", "--list", "release/*"], universal_newlines=True)
			if branches_output.strip():
				print("Found existing release branches:")
				for line in branches_output.strip().split('\n'):
					branch_name = line.strip().lstrip('* ').strip()
					print(f"  - {branch_name}")

				if typer.confirm("Delete existing release branches to proceed?"):
					for line in branches_output.strip().split('\n'):
						branch_name = line.strip().lstrip('* ').strip()
						if branch_name.startswith('release/'):
							version_part = branch_name.replace('release/', '')
							subprocess.run(["git", "flow", "release", "delete", version_part, "-f"])
							print(f"Deleted {branch_name}")
				else:
					print("Cannot proceed with existing release branches. Aborting.")
					return 1
		except subprocess.CalledProcessError:
			pass  # No existing release branches

		# Start git flow release
		result = subprocess.run(["git", "flow", "release", "start", f"{major}.{minor}.{patch}"])
		if result.returncode != 0:
			print("ERROR: Failed to start release branch")
			return 1

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

	# Check if master branch has unpushed commits
	try:
		result = subprocess.run(["git", "rev-list", "--count", "origin/master..master"],
		                       capture_output=True, text=True)
		unpushed_commits = int(result.stdout.strip()) if result.returncode == 0 else 0

		if unpushed_commits > 0:
			print(f"Warning: Master branch has {unpushed_commits} unpushed commits.")
			if typer.confirm("Push master branch to origin before finishing release?"):
				print("Pushing master branch...")
				subprocess.run(["git", "push", "origin", "master"])
			else:
				print("Continuing without pushing master. This may cause the release to fail.")
	except Exception as e:
		print(f"Warning: Could not check master branch status: {e}")

	# Finish release without pushing all tags to avoid conflicts
	result = subprocess.run(shlex.split(f"git flow release finish {major}.{minor}.{patch} -m \"Release v{major}.{minor}.{patch}\" --pushproduction"))

	# Push only the new release tag
	if result.returncode == 0:
		print(f"Pushing release tag v{major}.{minor}.{patch}...")
		tag_result = subprocess.run(["git", "push", "origin", f"v{major}.{minor}.{patch}"])
		if tag_result.returncode != 0:
			print(f"ERROR: Failed to push tag v{major}.{minor}.{patch}")
			print("To manually push the tag later:")
			print(f"   git push origin v{major}.{minor}.{patch}")
			result = tag_result

	if result.returncode != 0:
		print("ERROR: Git flow release finish failed!")
		print("\nPossible causes:")
		print("- Merge conflicts during merge to stable")
		print("- Network issues during push")
		print("- Branch protection rules")
		print("\nTo recover:")
		print("1. Check git status for conflicts")
		print("2. Resolve any merge conflicts")
		print("3. Complete manually with:")
		print(f"   git flow release finish {major}.{minor}.{patch} -m \"Release v{major}.{minor}.{patch}\"")
		print("4. Then push branches and tags:")
		print("   git push origin master")
		print("   git push origin stable")
		print("   git push origin --tags")
		return 1

	print("Release finished successfully")

	# Add unreleased section back to changelog for future development
	log_files = ["CHANGELOG.md", "CHANGES.md", "RELEASE_NOTES.md"]
	changelog_modified = False
	modified_file = None

	for log_file in log_files:
		if os.path.isfile(log_file):
			with open(log_file, "r") as f:
				content = f.read()

			# Add unreleased section at the top
			if not content.startswith("## Unreleased"):
				with open(log_file, "w") as f:
					f.write("## Unreleased\n\n")
					f.write(content)
				print(f"Added unreleased section to {log_file}")
				changelog_modified = True
				modified_file = log_file
			break

	# Commit and push the changelog changes
	if changelog_modified:
		try:
			subprocess.run(["git", "add", modified_file], check=True)
			subprocess.run(["git", "commit", "-m", "chore: add unreleased section to changelog for future development"], check=True)
			subprocess.run(["git", "push", "origin", "master"], check=True)
			print(f"Committed and pushed changelog changes")
		except subprocess.CalledProcessError as e:
			print(f"Warning: Failed to commit/push changelog changes: {e}")
			print("You may need to commit and push manually:")

	# Final cleanup: ensure no release branches remain
	try:
		branches_output = subprocess.check_output(["git", "branch", "--list", "release/*"], universal_newlines=True)
		if branches_output.strip():
			print("Cleaning up remaining release branches...")
			for line in branches_output.strip().split('\n'):
				branch_name = line.strip().lstrip('* ').strip()
				if branch_name.startswith('release/'):
					version_part = branch_name.replace('release/', '')
					subprocess.run(["git", "flow", "release", "delete", version_part, "-f"], check=False)
					print(f"Cleaned up {branch_name}")
	except subprocess.CalledProcessError:
		pass  # No release branches to clean up


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