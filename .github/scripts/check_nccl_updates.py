#!/usr/bin/env python3
"""Checks for nccl-tests image updates and modifies build-images.yaml."""

import re
import subprocess
import sys
from pathlib import Path

TAG_PATTERN = re.compile(
    r"^(\d+\.\d+\.\d+)-devel-(ubuntu\d+\.\d+)-nccl(\d+\.\d+\.\d+-\d+)-([a-f0-9]+)$"
)
IMAGE_PREFIX = "ghcr.io/coreweave/nccl-tests:"
WORKFLOW_FILE = Path(".github/workflows/build-images.yaml")


def parse_tag(tag: str) -> dict | None:
    """Parse an nccl-tests image tag into its components."""
    match = TAG_PATTERN.match(tag)
    if not match:
        return None
    return {
        "cuda": match.group(1),
        "os": match.group(2),
        "nccl": match.group(3),
        "sha": match.group(4),
        "full_tag": tag,
    }


def nccl_version_tuple(version: str) -> tuple:
    """Convert an NCCL version string like '2.29.2-1' to a comparable tuple."""
    return tuple(int(p) for p in version.replace("-", ".").split("."))


def cuda_version_tuple(version: str) -> tuple:
    """Convert a CUDA version string like '12.9.1' to a comparable tuple."""
    return tuple(int(p) for p in version.split("."))


def cuda_short_name(cuda_version: str) -> str:
    """Generate a short CUDA name like 'cu129' from '12.9.1'."""
    parts = cuda_version.split(".")
    return f"cu{parts[0]}{parts[1]}"


def parse_current_config(content: str) -> list[dict]:
    """Extract nccl-tests image references from workflow file content."""
    entries = []
    pattern = re.compile(r"image:\s*" + re.escape(IMAGE_PREFIX) + r"(\S+)")
    for match in pattern.finditer(content):
        parsed = parse_tag(match.group(1))
        if parsed:
            entries.append(parsed)
    return entries


def find_updates(
    current_entries: list[dict], available_tags: list[str]
) -> tuple[list[tuple[str, str]], dict[str, list[dict]]]:
    """Compare current config against available tags to find updates.

    Groups tags by (cuda_short_name, os) so that CUDA patch bumps
    (e.g. 12.9.1 -> 12.9.2) are treated as updates to existing entries.

    Returns:
        updates: list of (old_tag, new_tag) replacements
        additions: dict of os_name -> list of entries for new CUDA versions
    """
    available = [parse_tag(t) for t in available_tags]
    available = [a for a in available if a is not None]

    # Group available tags by (cuda_short_name, os)
    available_by_group = {}
    for a in available:
        key = (cuda_short_name(a["cuda"]), a["os"])
        available_by_group.setdefault(key, []).append(a)

    # Find the best entry for each group: highest NCCL, then highest CUDA patch
    best_by_group = {}
    for key, entries in available_by_group.items():
        best = max(
            entries,
            key=lambda e: (nccl_version_tuple(e["nccl"]), cuda_version_tuple(e["cuda"])),
        )
        best_by_group[key] = best

    current_os_set = set()
    current_groups = set()
    updates = []

    for entry in current_entries:
        group = (cuda_short_name(entry["cuda"]), entry["os"])
        current_os_set.add(entry["os"])
        current_groups.add(group)

        if group in best_by_group:
            best = best_by_group[group]
            cur_nccl = nccl_version_tuple(entry["nccl"])
            best_nccl = nccl_version_tuple(best["nccl"])
            cur_cuda = cuda_version_tuple(entry["cuda"])
            best_cuda = cuda_version_tuple(best["cuda"])

            if best_nccl > cur_nccl or (best_nccl == cur_nccl and best_cuda > cur_cuda):
                updates.append((entry["full_tag"], best["full_tag"]))

    # Find new CUDA versions for tracked OS versions
    additions = {}
    for group, best in best_by_group.items():
        short_name, os_name = group
        if os_name in current_os_set and group not in current_groups:
            additions.setdefault(os_name, []).append(best)

    for os_name in additions:
        additions[os_name].sort(key=lambda e: cuda_version_tuple(e["cuda"]))

    return updates, additions


def apply_updates(
    content: str,
    updates: list[tuple[str, str]],
    additions: dict[str, list[dict]],
) -> str:
    """Apply tag replacements and new CUDA entries to workflow file content."""
    for old_tag, new_tag in updates:
        content = content.replace(f"{IMAGE_PREFIX}{old_tag}", f"{IMAGE_PREFIX}{new_tag}")

    if additions:
        lines = content.split("\n")
        # Find insertion points per OS, processing bottom-up to preserve indices
        insertion_points = []
        for os_name, entries in additions.items():
            last_image_line = None
            for i, line in enumerate(lines):
                if IMAGE_PREFIX in line and f"-{os_name}-" in line:
                    last_image_line = i
            if last_image_line is not None:
                insertion_points.append((last_image_line, os_name, entries))

        insertion_points.sort(key=lambda x: x[0], reverse=True)

        for line_idx, os_name, entries in insertion_points:
            entries.sort(key=lambda e: cuda_version_tuple(e["cuda"]))
            new_lines = []
            for entry in entries:
                name = cuda_short_name(entry["cuda"])
                new_lines.append(f"        - name: {name}")
                new_lines.append(f"          image: {IMAGE_PREFIX}{entry['full_tag']}")
            lines = lines[: line_idx + 1] + new_lines + lines[line_idx + 1 :]

        content = "\n".join(lines)

    return content


def fetch_available_tags() -> list[str]:
    """Query the GHCR packages API for available nccl-tests tags."""
    result = subprocess.run(
        [
            "gh", "api", "--paginate",
            "/orgs/coreweave/packages/container/nccl-tests/versions",
            "-q", ".[].metadata.container.tags[]",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return [t for t in result.stdout.strip().split("\n") if t]


def main():
    content = WORKFLOW_FILE.read_text()
    current_entries = parse_current_config(content)
    print(f"Found {len(current_entries)} current nccl-tests entries")

    available_tags = fetch_available_tags()
    print(f"Found {len(available_tags)} available tags in registry")

    updates, additions = find_updates(current_entries, available_tags)

    if not updates and not additions:
        print("No updates found.")
        return

    if updates:
        print(f"\nNCCL version updates ({len(updates)}):")
        for old, new in updates:
            print(f"  {old}")
            print(f"  -> {new}")

    if additions:
        for os_name, entries in additions.items():
            print(f"\nNew CUDA versions for {os_name} ({len(entries)}):")
            for entry in entries:
                print(f"  {cuda_short_name(entry['cuda'])} ({entry['full_tag']})")

    new_content = apply_updates(content, updates, additions)
    WORKFLOW_FILE.write_text(new_content)
    print("\nUpdated workflow file.")


if __name__ == "__main__":
    main()
