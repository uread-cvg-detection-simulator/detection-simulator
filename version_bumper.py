#!/usr/bin/env python3

import json
import os
import re
import shlex
import subprocess
import sys
from enum import Enum
from typing import List

import typer
from dotenv import load_dotenv
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich import print as rprint
from rich.progress import track

# Load environment variables from .env file
load_dotenv()

# Initialize rich console
console = Console()

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

	# Print version change with rich formatting
	version_panel = Panel(
		f"[bold green]{version}[/bold green] → [bold blue]{major}.{minor}.{patch}[/bold blue]",
		title="[bold]Version Bump[/bold]",
		border_style="cyan"
	)
	console.print(version_panel)

	# Update files if not a dry run
	if not dry_run:

		# Check if any unstaged changes
		if subprocess.run(["git", "diff", "--exit-code"]).returncode != 0:
			console.print("[red]⚠️  There are unstaged changes. Please commit or stash them before continuing.[/red]")
			return None

		# Check if ok to proceed
		if not typer.confirm(f"Are you sure you want to bump version to {major}.{minor}.{patch}?"):
			return None

		console.print(Panel("[bold green]Starting Release Process[/bold green]", border_style="green"))

		# Check for existing release branches and clean them up
		try:
			branches_output = subprocess.check_output(["git", "branch", "--list", "release/*"], universal_newlines=True)
			if branches_output.strip():
				branch_list = []
				for line in branches_output.strip().split('\n'):
					branch_name = line.strip().lstrip('* ').strip()
					branch_list.append(f"• {branch_name}")

				warning_panel = Panel(
					"\n".join(branch_list),
					title="[bold yellow]⚠️  Existing Release Branches Found[/bold yellow]",
					border_style="yellow"
				)
				console.print(warning_panel)

				if typer.confirm("Delete existing release branches to proceed?"):
					with console.status("[bold green]Cleaning up release branches...[/bold green]") as status:
						for line in branches_output.strip().split('\n'):
							branch_name = line.strip().lstrip('* ').strip()
							if branch_name.startswith('release/'):
								version_part = branch_name.replace('release/', '')
								subprocess.run(["git", "flow", "release", "delete", version_part, "-f"])
								console.print(f"[green]✓[/green] Deleted {branch_name}")
				else:
					console.print("[red]❌ Cannot proceed with existing release branches. Aborting.[/red]")
					return 1
		except subprocess.CalledProcessError:
			pass  # No existing release branches

		# Start git flow release
		with console.status("[bold blue]Creating release branch...[/bold blue]") as status:
			result = subprocess.run(["git", "flow", "release", "start", f"{major}.{minor}.{patch}"])
			if result.returncode != 0:
				console.print("[red]❌ ERROR: Failed to start release branch[/red]")
				return 1
			console.print(f"[green]✓[/green] Created release branch [bold]release/{major}.{minor}.{patch}[/bold]")

		console.print(Panel("[bold blue]Updating Project Files[/bold blue]", border_style="blue"))

		# Update project.godot
		update_project_godot(project_file, major, minor, patch)

		# Update .zenodo.json with specific release URL
		update_zenodo_json(major, minor, patch)

		# Update changelogs
		log_files = ["CHANGELOG.md", "CHANGES.md", "RELEASE_NOTES.md"]

		log_found = update_changelogs(log_files, major, minor, patch)

		if not log_found:
			console.print(f"[yellow]⚠️  No log file found out of [{','.join(log_files)}]. Skipping...[/yellow]")
		else:
			console.print("[green]✓[/green] Updated changelog")

		# Stage changelog changes (version replacement already happened)
		if log_found:
			# Find which changelog file was updated
			changelog_file = None
			for log_file in log_files:
				if os.path.isfile(log_file):
					changelog_file = log_file
					break

			if changelog_file:
				subprocess.run(["git", "add", changelog_file])
				console.print(f"[green]✓[/green] Staged {changelog_file} changes")

			# Ask if user wants to edit changelog
			if typer.confirm("Do you want to edit the changelog before committing?"):
				if changelog_file:
					editor = os.environ.get('EDITOR', 'nano')
					console.print(f"[blue]📝 Opening {changelog_file} with {editor}...[/blue]")
					subprocess.run([editor, changelog_file])

					if typer.confirm("Are you satisfied with the changelog changes?"):
						subprocess.run(["git", "add", changelog_file])
						console.print("[green]✓[/green] Updated changelog changes staged")
					else:
						console.print("[yellow]⚠️  Changelog edits not staged. Original version changes are still staged.[/yellow]")

		# Ask if user wants to commit the changes
		commit_panel = Panel(
			f"Ready to commit version bump changes:\n\n"
			f"• Updated project.godot to v{major}.{minor}.{patch}\n"
			f"• Updated .zenodo.json with release information\n" +
			(f"• Updated changelog with version {major}.{minor}.{patch}" if log_found else ""),
			title="[bold green]📦 Commit Version Bump Changes?[/bold green]",
			border_style="green"
		)
		console.print(commit_panel)

		if typer.confirm("Do you want to commit all the version bump changes?"):
			with console.status("[bold green]Committing changes...[/bold green]") as status:
				subprocess.run(["git", "commit", "-m", f"Bump version to {major}.{minor}.{patch}"])
				console.print("[green]✓[/green] Changes committed")

			# Ask user if want to finish release
			if typer.confirm("Do you want to finish the release?"):
				run_finish_release(major, minor, patch)
				success_panel = Panel(
					"[bold green]🎉 Release completed successfully![/bold green]",
					border_style="green"
				)
				console.print(success_panel)
			else:
				info_panel = Panel(
					f"Release branch '[bold]release/{major}.{minor}.{patch}[/bold]' created with changes committed.\n\n"
					"You can finish the release later with:\n"
					"[bold cyan]./version_bumper.py release[/bold cyan]",
					title="[bold blue]📋 Next Steps[/bold blue]",
					border_style="blue"
				)
				console.print(info_panel)
		else:
			next_steps = Panel(
				f"You are now on release branch '[bold]release/{major}.{minor}.{patch}[/bold]'.\n\n"
				"Available actions:\n"
				"• Review staged changes: [bold cyan]git status[/bold cyan]\n"
				"• Commit manually: [bold cyan]git commit -m 'Your message'[/bold cyan]\n"
				"• Continue with: [bold cyan]./version_bumper.py release[/bold cyan]\n"
				f"• Or revert: [bold cyan]git flow release delete {major}.{minor}.{patch} -f[/bold cyan]",
				title="[bold yellow]⚠️  Changes Staged but Not Committed[/bold yellow]",
				border_style="yellow"
			)
			console.print(next_steps)

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


def get_version_changelog(major: int, minor: int, patch: int) -> str:
	"""
	Extract changelog content for a specific version from CHANGELOG.md

	:param major: Major version
	:param minor: Minor version
	:param patch: Patch version
	:return: Changelog content for the version, or empty string if not found
	"""
	version_str = f"{major}.{minor}.{patch}"
	log_files = ["CHANGELOG.md", "CHANGES.md", "RELEASE_NOTES.md"]

	for log_file in log_files:
		if not os.path.exists(log_file):
			continue

		try:
			with open(log_file, "r") as f:
				content = f.read()

			# Look for version section (e.g., "## 1.0.0")
			version_pattern = rf"^## {re.escape(version_str)}.*?$"
			next_version_pattern = r"^## \d+\.\d+\.\d+"

			lines = content.split('\n')
			version_start = None

			# Find the start of this version's section
			for i, line in enumerate(lines):
				if re.match(version_pattern, line.strip()):
					version_start = i + 1  # Start after the header
					break

			if version_start is None:
				continue  # Version not found in this file

			# Find the end of this version's section
			version_end = len(lines)
			for i in range(version_start, len(lines)):
				if re.match(next_version_pattern, lines[i].strip()):
					version_end = i
					break

			# Extract and clean the changelog content
			changelog_lines = lines[version_start:version_end]

			# Remove empty lines from start and end
			while changelog_lines and not changelog_lines[0].strip():
				changelog_lines.pop(0)
			while changelog_lines and not changelog_lines[-1].strip():
				changelog_lines.pop()

			changelog_content = '\n'.join(changelog_lines)

			if changelog_content.strip():
				return changelog_content.strip()

		except Exception as e:
			console.print(f"[yellow]⚠️  Could not read {log_file}: {e}[/yellow]")
			continue

	return ""  # No changelog content found


def update_zenodo_json(major: int, minor: int, patch: int):
	"""
	Update .zenodo.json with specific release URL

	:param major: Major version
	:param minor: Minor version
	:param patch: Patch version
	"""
	zenodo_file = ".zenodo.json"

	if not os.path.exists(zenodo_file):
		console.print(f"[yellow]⚠️  No {zenodo_file} found. Skipping...[/yellow]")
		return

	try:
		# Read current zenodo.json
		with open(zenodo_file, "r") as f:
			zenodo_data = json.load(f)

		# Get repository name from git remote
		try:
			result = subprocess.run(
				["git", "config", "--get", "remote.origin.url"],
				capture_output=True, text=True, check=True
			)
			remote_url = result.stdout.strip()

			# Extract repository path from various URL formats
			# Handle both SSH and HTTPS URLs
			if remote_url.startswith("git@"):
				# SSH format: git@github.com:user/repo.git
				repo_path = remote_url.split(":")[-1].replace(".git", "")
			else:
				# HTTPS format: https://github.com/user/repo.git
				repo_path = "/".join(remote_url.split("/")[-2:]).replace(".git", "")

		except subprocess.CalledProcessError:
			# Fallback to default if git remote fails
			repo_path = "jonboland/detection-simulator"
			console.print(f"[yellow]⚠️  Could not get git remote, using default: {repo_path}[/yellow]")

		# Build version-specific description
		new_version = f"v{major}.{minor}.{patch}"
		release_url = f"https://github.com/{repo_path}/releases/tag/{new_version}"

		# Get changelog content for this version
		changelog_content = get_version_changelog(major, minor, patch)

		# Create new description with version-specific information
		base_description = """A tool for simulating the detection and tracking of objects in a top-down 2D environment. Exports data into JSON format containing x/y coordinates and timestamps for testing and validating object detection and tracking algorithms.

## Features

- **Configurable Agents**: Speed and acceleration settings with waypoint linking for synchronized movement and timed waiting
- **Vehicle Interactions**: Person agents can enter and exit vehicle type agents
- **Dynamic Event System**: Automated events generated when entering/exiting vehicles, plus manual events with configurable conditions
- **Sensors**: Configurable field of view and range, producing detection data only for agents within sensor coverage
- **Background Images**: Configurable size and scale support
- **Export Capabilities**: JSON files for each agent and sensor with coordinate and timestamp data
- **Cross-Platform**: Available for Windows, Linux, and macOS"""

		# Add version-specific changelog if available
		if changelog_content:
			version_section = f"\n\n## Version {major}.{minor}.{patch} Changes\n\n{changelog_content}"
		else:
			version_section = f"\n\n## Version {major}.{minor}.{patch}\n\nSee the GitHub release page for detailed changes."

		# Add download section
		download_section = f"\n\n## Download\n\nPre-compiled binaries for this version are available at: {release_url}\n\nThis Zenodo archive contains the source code for citation and archival purposes."

		# Combine all sections
		new_description = base_description + version_section + download_section
		zenodo_data["description"] = new_description

		# Write updated zenodo.json
		with open(zenodo_file, "w") as f:
			json.dump(zenodo_data, f, indent=2)

		# Stage the file
		subprocess.run(["git", "add", zenodo_file])
		console.print(f"[green]✓[/green] Updated {zenodo_file} with release URL: {release_url}")

	except json.JSONDecodeError as e:
		console.print(f"[red]❌ ERROR: Invalid JSON in {zenodo_file}: {e}[/red]")
	except Exception as e:
		console.print(f"[red]❌ ERROR: Failed to update {zenodo_file}: {e}[/red]")


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

	console.print(Panel(f"[bold blue]Finishing Release v{major}.{minor}.{patch}[/bold blue]", border_style="blue"))

	# Check if master branch has unpushed commits
	try:
		result = subprocess.run(["git", "rev-list", "--count", "origin/master..master"],
		                       capture_output=True, text=True)
		unpushed_commits = int(result.stdout.strip()) if result.returncode == 0 else 0

		if unpushed_commits > 0:
			warning_panel = Panel(
				f"Master branch has [bold red]{unpushed_commits}[/bold red] unpushed commits.",
				title="[bold yellow]⚠️  Warning[/bold yellow]",
				border_style="yellow"
			)
			console.print(warning_panel)
			if typer.confirm("Push master branch to origin before finishing release?"):
				with console.status("[bold green]Pushing master branch...[/bold green]") as status:
					subprocess.run(["git", "push", "origin", "master"])
					console.print("[green]✓[/green] Master branch pushed")
			else:
				console.print("[yellow]⚠️  Continuing without pushing master. This may cause the release to fail.[/yellow]")
	except Exception as e:
		console.print(f"[yellow]⚠️  Warning: Could not check master branch status: {e}[/yellow]")

	# Finish release without pushing all tags to avoid conflicts
	with console.status("[bold blue]Finishing git flow release...[/bold blue]") as status:
		result = subprocess.run(shlex.split(f"git flow release finish {major}.{minor}.{patch} -m \"Release v{major}.{minor}.{patch}\" --pushproduction"))

	# Push only the new release tag
	if result.returncode == 0:
		with console.status(f"[bold green]Pushing release tag v{major}.{minor}.{patch}...[/bold green]") as status:
			tag_result = subprocess.run(["git", "push", "origin", f"v{major}.{minor}.{patch}"])
			if tag_result.returncode != 0:
				error_panel = Panel(
					f"Failed to push tag [bold]v{major}.{minor}.{patch}[/bold]\n\n"
					"To manually push the tag later:\n"
					f"[bold cyan]git push origin v{major}.{minor}.{patch}[/bold cyan]",
					title="[bold red]❌ Error[/bold red]",
					border_style="red"
				)
				console.print(error_panel)
				result = tag_result
			else:
				console.print(f"[green]✓[/green] Pushed tag [bold]v{major}.{minor}.{patch}[/bold]")

	if result.returncode != 0:
		error_panel = Panel(
			"[bold red]Git flow release finish failed![/bold red]\n\n"
			"[bold]Possible causes:[/bold]\n"
			"• Merge conflicts during merge to stable\n"
			"• Network issues during push\n"
			"• Branch protection rules\n\n"
			"[bold]To recover:[/bold]\n"
			"1. Check git status for conflicts\n"
			"2. Resolve any merge conflicts\n"
			"3. Complete manually with:\n"
			f"   [bold cyan]git flow release finish {major}.{minor}.{patch} -m \"Release v{major}.{minor}.{patch}\"[/bold cyan]\n"
			"4. Then push branches and tags:\n"
			"   [bold cyan]git push origin master[/bold cyan]\n"
			"   [bold cyan]git push origin stable[/bold cyan]\n"
			"   [bold cyan]git push origin --tags[/bold cyan]",
			title="[bold red]❌ Release Failed[/bold red]",
			border_style="red"
		)
		console.print(error_panel)
		return 1

	console.print("[green]✓[/green] Release finished successfully")

	# Add unreleased section back to changelog for future development
	console.print(Panel("[bold blue]Post-Release Setup[/bold blue]", border_style="blue"))

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
				console.print(f"[green]✓[/green] Added unreleased section to {log_file}")
				changelog_modified = True
				modified_file = log_file
			break

	# Commit and push the changelog changes
	if changelog_modified:
		try:
			with console.status("[bold green]Committing changelog updates...[/bold green]") as status:
				subprocess.run(["git", "add", modified_file], check=True)
				subprocess.run(["git", "commit", "-m", "chore: add unreleased section to changelog for future development"], check=True)
				subprocess.run(["git", "push", "origin", "master"], check=True)
				console.print("[green]✓[/green] Committed and pushed changelog changes")
		except subprocess.CalledProcessError as e:
			warning_panel = Panel(
				f"Failed to commit/push changelog changes: {e}\n\n"
				"You may need to commit and push manually",
				title="[bold yellow]⚠️  Warning[/bold yellow]",
				border_style="yellow"
			)
			console.print(warning_panel)

	# Final cleanup: ensure no release branches remain
	try:
		branches_output = subprocess.check_output(["git", "branch", "--list", "release/*"], universal_newlines=True)
		if branches_output.strip():
			with console.status("[bold yellow]Cleaning up remaining release branches...[/bold yellow]") as status:
				for line in branches_output.strip().split('\n'):
					branch_name = line.strip().lstrip('* ').strip()
					if branch_name.startswith('release/'):
						version_part = branch_name.replace('release/', '')
						subprocess.run(["git", "flow", "release", "delete", version_part, "-f"], check=False)
						console.print(f"[green]✓[/green] Cleaned up {branch_name}")
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
		console.print(f"[red]❌ ERROR: Could not find {project_file}[/red]")
		return 1

	with open(project_file, "r") as f:
		lines = f.readlines()

		for line in lines:
			if "config/version=" in line:
				version = line.split("=")[1].strip()
				version = version.replace("\"", "")

				version_panel = Panel(
					f"[bold blue]{version}[/bold blue]",
					title="[bold]Current Version[/bold]",
					border_style="cyan"
				)
				console.print(version_panel)
				return 0
		else:
			console.print("[red]❌ No version found in project.godot[/red]")
			return 1


if __name__ == '__main__':
	sys.exit(app())