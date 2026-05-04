#!/usr/bin/env python3
"""Tests for the nccl-tests update checker."""

import unittest

from check_nccl_updates import (
    IMAGE_PREFIX,
    apply_updates,
    cuda_short_name,
    cuda_version_tuple,
    find_updates,
    nccl_version_tuple,
    parse_current_config,
    parse_tag,
)


class TestParseTag(unittest.TestCase):
    def test_valid_tag(self):
        result = parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e")
        self.assertEqual(
            result,
            {
                "cuda": "12.9.1",
                "os": "ubuntu24.04",
                "nccl": "2.29.2-1",
                "sha": "2276a5e",
                "full_tag": "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
            },
        )

    def test_invalid_tags(self):
        self.assertIsNone(parse_tag("latest"))
        self.assertIsNone(parse_tag(""))
        self.assertIsNone(parse_tag("not-a-tag"))
        self.assertIsNone(
            parse_tag("12.9.1-runtime-ubuntu24.04-nccl2.29.2-1-2276a5e")
        )

    def test_different_versions(self):
        result = parse_tag("13.1.0-devel-ubuntu22.04-nccl2.27.5-1-d5a135d")
        self.assertEqual(result["cuda"], "13.1.0")
        self.assertEqual(result["os"], "ubuntu22.04")
        self.assertEqual(result["nccl"], "2.27.5-1")
        self.assertEqual(result["sha"], "d5a135d")


class TestVersionTuples(unittest.TestCase):
    def test_nccl_version_tuple(self):
        self.assertEqual(nccl_version_tuple("2.29.2-1"), (2, 29, 2, 1))
        self.assertEqual(nccl_version_tuple("2.27.5-1"), (2, 27, 5, 1))

    def test_nccl_version_comparison(self):
        self.assertGreater(
            nccl_version_tuple("2.30.0-1"), nccl_version_tuple("2.29.2-1")
        )
        self.assertGreater(
            nccl_version_tuple("2.29.2-2"), nccl_version_tuple("2.29.2-1")
        )
        self.assertEqual(
            nccl_version_tuple("2.29.2-1"), nccl_version_tuple("2.29.2-1")
        )

    def test_cuda_version_tuple(self):
        self.assertEqual(cuda_version_tuple("12.9.1"), (12, 9, 1))
        self.assertEqual(cuda_version_tuple("13.0.1"), (13, 0, 1))

    def test_cuda_version_comparison(self):
        self.assertGreater(
            cuda_version_tuple("13.0.1"), cuda_version_tuple("12.9.1")
        )
        self.assertGreater(
            cuda_version_tuple("12.9.1"), cuda_version_tuple("12.8.1")
        )


class TestCudaShortName(unittest.TestCase):
    def test_short_names(self):
        self.assertEqual(cuda_short_name("12.9.1"), "cu129")
        self.assertEqual(cuda_short_name("13.0.1"), "cu130")
        self.assertEqual(cuda_short_name("12.2.2"), "cu122")
        self.assertEqual(cuda_short_name("13.1.0"), "cu131")


class TestParseCurrentConfig(unittest.TestCase):
    def test_extracts_entries(self):
        content = (
            "      cuda:\n"
            "        - name: cu129\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
            "        - name: cu130\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "13.0.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
        )
        entries = parse_current_config(content)
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[0]["cuda"], "12.9.1")
        self.assertEqual(entries[1]["cuda"], "13.0.1")

    def test_handles_no_entries(self):
        entries = parse_current_config("no images here")
        self.assertEqual(len(entries), 0)


class TestFindUpdates(unittest.TestCase):
    def test_nccl_version_bump(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 1)
        self.assertEqual(
            updates[0][0],
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
        )
        self.assertEqual(
            updates[0][1],
            "12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
        )
        self.assertEqual(len(additions), 0)

    def test_no_changes(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 0)
        self.assertEqual(len(additions), 0)

    def test_sha_only_change_ignored(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-fffffff",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 0)

    def test_new_cuda_version(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
            "13.2.0-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 0)
        self.assertIn("ubuntu24.04", additions)
        self.assertEqual(len(additions["ubuntu24.04"]), 1)
        self.assertEqual(additions["ubuntu24.04"][0]["cuda"], "13.2.0")

    def test_new_cuda_for_untracked_os_ignored(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
            "12.9.1-devel-ubuntu26.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 0)
        self.assertEqual(len(additions), 0)

    def test_cuda_patch_bump_with_nccl_bump(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.2-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 1)
        self.assertEqual(
            updates[0][1],
            "12.9.2-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
        )
        self.assertEqual(len(additions), 0)

    def test_cuda_patch_bump_same_nccl(self):
        """CUDA patch bump with same NCCL version should still update."""
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.2-devel-ubuntu24.04-nccl2.29.2-1-abc1234",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 1)
        self.assertEqual(
            updates[0][1],
            "12.9.2-devel-ubuntu24.04-nccl2.29.2-1-abc1234",
        )

    def test_multiple_os_updates(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
            parse_tag("12.9.1-devel-ubuntu22.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
            "12.9.1-devel-ubuntu22.04-nccl2.30.0-1-abc1234",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 2)

    def test_does_not_downgrade(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234"),
        ]
        available = [
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 0)

    def test_ignores_unparseable_tags(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "latest",
            "12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
            "",
            "some-random-tag",
        ]
        updates, additions = find_updates(current, available)
        self.assertEqual(len(updates), 1)

    def test_min_cuda_filters_old_additions(self):
        current = [
            parse_tag("12.9.1-devel-ubuntu22.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.9.1-devel-ubuntu22.04-nccl2.29.2-1-2276a5e",
            "11.7.1-devel-ubuntu22.04-nccl2.14.3-1-e73246a",
            "12.0.1-devel-ubuntu22.04-nccl2.23.4-1-c58f522",
            "13.2.0-devel-ubuntu22.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available, min_cuda="12.9")
        self.assertEqual(len(updates), 0)
        self.assertEqual(len(additions["ubuntu22.04"]), 1)
        self.assertEqual(additions["ubuntu22.04"][0]["cuda"], "13.2.0")

    def test_min_cuda_does_not_affect_existing_updates(self):
        """NCCL bumps for existing entries below the floor still apply."""
        current = [
            parse_tag("12.2.2-devel-ubuntu22.04-nccl2.27.5-1-d5a135d"),
            parse_tag("12.9.1-devel-ubuntu22.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "12.2.2-devel-ubuntu22.04-nccl2.27.7-1-a33e52a",
            "12.9.1-devel-ubuntu22.04-nccl2.30.0-1-abc1234",
        ]
        updates, additions = find_updates(current, available, min_cuda="12.9")
        self.assertEqual(len(updates), 2)

    def test_min_cuda_boundary_is_inclusive(self):
        current = [
            parse_tag("13.0.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
        ]
        available = [
            "13.0.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
            "12.9.0-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
            "12.8.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
        ]
        updates, additions = find_updates(current, available, min_cuda="12.9")
        self.assertEqual(len(additions["ubuntu24.04"]), 1)
        self.assertEqual(additions["ubuntu24.04"][0]["cuda"], "12.9.0")


class TestApplyUpdates(unittest.TestCase):
    def test_replace_tag(self):
        content = (
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
        )
        updates = [
            (
                "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
                "12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
            ),
        ]
        result = apply_updates(content, updates, {})
        self.assertIn("nccl2.30.0-1-abc1234", result)
        self.assertNotIn("nccl2.29.2-1-2276a5e", result)

    def test_add_new_cuda(self):
        content = (
            "      cuda:\n"
            "        - name: cu129\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
            "        - name: cu130\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "13.0.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
            "      slurm_pmix_version: pmix2\n"
        )
        additions = {
            "ubuntu24.04": [
                parse_tag("13.2.0-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
            ],
        }
        result = apply_updates(content, [], additions)
        self.assertIn("- name: cu132", result)
        self.assertIn("13.2.0-devel-ubuntu24.04", result)
        lines = result.split("\n")
        cu132_idx = next(i for i, l in enumerate(lines) if "cu132" in l)
        pmix_idx = next(
            i for i, l in enumerate(lines) if "slurm_pmix_version" in l
        )
        self.assertLess(cu132_idx, pmix_idx)

    def test_add_multiple_cuda_sorted(self):
        content = (
            "      cuda:\n"
            "        - name: cu129\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
            "      slurm_pmix_version: pmix2\n"
        )
        additions = {
            "ubuntu24.04": [
                parse_tag("13.2.0-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
                parse_tag("13.1.0-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
            ],
        }
        result = apply_updates(content, [], additions)
        lines = result.split("\n")
        cu131_idx = next(i for i, l in enumerate(lines) if "cu131" in l)
        cu132_idx = next(i for i, l in enumerate(lines) if "cu132" in l)
        self.assertLess(cu131_idx, cu132_idx)

    def test_additions_across_multiple_os(self):
        content = (
            "      cuda:\n"
            "        - name: cu129\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
            "      slurm_pmix_version: pmix2\n"
            "      cuda:\n"
            "        - name: cu129\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu22.04-nccl2.29.2-1-2276a5e\n"
            "      slurm_pmix_version: pmix2\n"
        )
        additions = {
            "ubuntu24.04": [
                parse_tag("13.2.0-devel-ubuntu24.04-nccl2.29.2-1-2276a5e"),
            ],
            "ubuntu22.04": [
                parse_tag("13.2.0-devel-ubuntu22.04-nccl2.29.2-1-2276a5e"),
            ],
        }
        result = apply_updates(content, [], additions)
        self.assertIn("13.2.0-devel-ubuntu24.04", result)
        self.assertIn("13.2.0-devel-ubuntu22.04", result)

    def test_combined_updates_and_additions(self):
        content = (
            "      cuda:\n"
            "        - name: cu129\n"
            "          image: ghcr.io/coreweave/nccl-tests:"
            "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e\n"
            "      slurm_pmix_version: pmix2\n"
        )
        updates = [
            (
                "12.9.1-devel-ubuntu24.04-nccl2.29.2-1-2276a5e",
                "12.9.1-devel-ubuntu24.04-nccl2.30.0-1-abc1234",
            ),
        ]
        additions = {
            "ubuntu24.04": [
                parse_tag("13.2.0-devel-ubuntu24.04-nccl2.30.0-1-abc1234"),
            ],
        }
        result = apply_updates(content, updates, additions)
        self.assertIn("nccl2.30.0-1-abc1234", result)
        self.assertNotIn("nccl2.29.2-1-2276a5e", result)
        self.assertIn("cu132", result)


if __name__ == "__main__":
    unittest.main()
