# Slurm Patches

This file explains the patches in this directory, why they exist, and reasons why they are not
likely to be added to the upstream code.

## 0001-max-server-threads

This patch increases the maximum number of server threads allowed in `slurmctld`. The value here is
roughly equivalent to the maximum number of nodes in a cluster. This increase prevents artificial
bottlenecks on threads when handling communication for nodes. Initially, dynamic nodes in Slurm did
not support fan-out, so all communications were directly from the controller. When handling large
jobs with many start/end operations, the messages could get stuck waiting for threads. This
bottleneck artificially limits and, in many cases, times out communications with the controller.
CoreWeave observed this bottleneck as cluster sizes reached 500 to 1000 nodes. We have observed that
setting the maximum number of server threads near or greater than the maximum number of nodes
prevents this bottleneck.

When we discussed this with the upstream maintainers, the communication we received indicated that
we could test this setting, but the upstream code has no plan to adjust the value. The upstream
solution is to use fan-out. Although fan-out is now available with dynamic nodes, we have
experienced issues with this option. We prefer to increase the maximum number of server threads as a
solution.

## 0002-agent-thread

This patch also increases the maximum threads available to process messages, with a slightly
different effect than the `0001-max-server-threads` patch. This patch addresses the same
bottlenecking behavior and communication timeouts we observed in large clusters. Like the prior
patch, the upstream maintainers are not considering changing this value, and prefer reducing the
controller load with fan-out.

## 0003-revert-no-dynamic-sort

This patch was originally applied to the upstream code in response to
[a bug we filed](https://support.schedmd.com/show_bug.cgi?id=16295), but was later reverted because
the patch also caused issues in other cases.

The sort order of nodes impacts how jobs are scheduled, and the way nodes are named reflects the
general network topology. If the nodes are not sorted, the scheduling can be non-optimal. We have
enabled the topology file to help optimize scheduling, but that has some other side effects, and not
all users are familiar with using topology files.

Since backing out the patch, the upstream project has not provided us with any further updates. If
this is fixed in the upstream code, then this patch will no longer be required.

## 0004-rest-get-node-default-flags

This patch is a workaround for a bug in `slurmctld` that causes the controller to crash with a
memory access error. We have
[a bug tracking this issue](https://support.schedmd.com/show_bug.cgi?id=20543) in the upstream
project.

Initially, we made a patch to `slurmctld`. That patch was invasive, so we elected to handle the
issue differently by not requesting details when accessing node information with `slurmrestd`.
However, we encountered [another bug](https://support.schedmd.com/show_bug.cgi?id=20559) with
`slurmrestd` with that approach.

This patch is a fast way to fix the second bug that works for our use case because we never need to
set the `SHOW_DETAILS` flag on the request. If we stop using the REST API for our integration with
SUNK or the upstream project corrects one of the two existing bugs, then this patch is no longer
necessary.

## 0005-allow-persistent-none

This patch allows `slurmctld` to make persistent connections, except for the special cases of
federation and accounting. Those two cases have behaviors that aren't desirable for a generic,
persistent RPC connection.

This patch treats the initialization of `PERSIST_TYPE_NONE` persistent connections the same as
`PERSIST_TYPE_ACCT_UPDATE`. This behavior allows us to use persistent RPC connections with our
client library instead of making new connections for each message and should be more efficient.
We have not submitted this to the upstream project because their current stance is not to address
the various other bugs we have reported and because this is considered a feature request, not a bug.

### 0006-allow-all-topology

This patch allows for both `topology/tree` and `topology/block` configuration to be present in the
topology configuration file `topology.conf`. This is done by updating the flags used in parsing the
file to ignore lines that do not match the expected contents for each of the topology plugins.
Without this patch when the topology plugins encounter a line that does not match their expected
format, `slurmctld` will exit with error
`something wrong with opening/reading /etc/slurm/topology.conf: Invalid argument`.

This is to allow generating information for both topology plugins in the `topology.conf` file by
SUNK without being conditional on which plugin is currently active. Validation that the expected
topology is loaded can still be done by `scontrol show topo`. Since the topology is generated it is
unlikely to have the type of formatting errors on lines that the prior behavior would catch.
Additionally, having a functional `slurmctld` even with "degradation" with respect to topology is
preferred over it being non-functional and taking the cluster down.

### 0007-cgroup-v2

This patch bypasses an issue with the Slurm cgroup/v2 plugin in which processes are incorrectly
reassigned to a new cgroup multiple times. When `slurmd` starts, the plugin creates a subdirectory
and moves the `slurmd` process into it to avoid interfering with other processes. This is part of an
effort to avoid issues when using a false cgroup root, but may occur more than once, leading to
`slurmd` failures. This modification ensures that this only occurs when `slurmd` starts for the
first time.

### 0008-job-skip-ids

This patch allows the user to enter job ids in an environment variable `SLURM_JOB_SKIP_IDS` on the
slurm chart. The ids provided will skip job processing from Slurm. This is useful when a job id
becomes corrupted. When Slurm has a corrupted job id, it will fail to process the job and lock up.
This will cause no new jobs to be able to processed or started. Skipping these jobs breaks the loop
and allows Slurm to continue to process jobs.

If upstream was to correct the root cause of why job ids become corrupted or handle corrupted job
ids gracefully then this patch would no longer be required.

### 0009-allowgaps

This patch allows for the
[allows gap](https://github.com/SchedMD/slurm/commit/700ca4f85f7ab5324d03235d5aa4392367626661)
functionality that upstream has created to be in the codebase but has not yet released as of 24-11-4.

This patch can be removed once Slurm releases the code that is on the master branch into a Slurm
version and that version has been merged into SUNK.

### 0010-topology-block-node-ranking

This patch reverts to alphabetical sorting of nodes by default when using the `topology/block`
plugin. The changes are taken directly from
[a commit](https://github.com/SchedMD/slurm/commit/e62665ac1baae7588e29b18aad70ae62d14515c5)
that is not part of an official Slurm release as of 24-11-4.

This patch can be removed once Slurm releases the code that is on the master branch into a Slurm
version and that version has been merged into SUNK.

### 0011-25.05-container-fixes

This is a collection of patches backported from the upcoming 25.05 release that include significant
changes to how slurm handles being ran with constrained resources. This is primarily backporting the
`TaskPluginParam=SlurmdSpecOverride` feature.
This includes the following commits:

- [SchedMD@9f89e6909](https://github.com/SchedMD/slurm/commit/9f89e69092088a8547daf9234ecf435300ee11c5)
- [SchedMD@43f168923](https://github.com/SchedMD/slurm/commit/43f1689235321c1dd8212d7f3907128c71921e56)
- [SchedMD@c7c0c1276](https://github.com/SchedMD/slurm/commit/c7c0c127662c75e4fe6f5323282b75581de68f7c)
- [SchedMD@86ff2d93a](https://github.com/SchedMD/slurm/commit/86ff2d93a34a04377cc56457bd25a66bd661a80e)
- [SchedMD@9f2ef82a7](https://github.com/SchedMD/slurm/commit/9f2ef82a785fb476439f5995368727eee77f530f)
- [SchedMD@24f72b117](https://github.com/SchedMD/slurm/commit/24f72b117faedcf49fcaf7335e627621c7e1003d)
- [SchedMD@0799f5374](https://github.com/SchedMD/slurm/commit/0799f5374d94950063d99ac1ddfd6f8c7556ce60)
- [SchedMD@8d2267795](https://github.com/SchedMD/slurm/commit/8d226779527fa701a7bd88ccdd19f2bd64d4ace3)
- [SchedMD@b1b63a242](https://github.com/SchedMD/slurm/commit/b1b63a24207271bf3dc8a2cadd9b4cf6b646d218)
- [SchedMD@7b283e471](https://github.com/SchedMD/slurm/commit/7b283e471cc2a6d2d446a461429839c14d521462)
- [SchedMD@7dab35e50](https://github.com/SchedMD/slurm/commit/7dab35e50e78a72586f73fb515ffdbef375b3152)
- [SchedMD@86ff2d93a](https://github.com/SchedMD/slurm/commit/86ff2d93a34a04377cc56457bd25a66bd661a80e)
- [SchedMD@57164b24d](https://github.com/SchedMD/slurm/commit/57164b24d8963fecaf31bf08c628ea80eb14b2dd)
- [SchedMD@cb5a93d4b](https://github.com/SchedMD/slurm/commit/cb5a93d4b70f6f60a27a7f829093c32c225ae2e1)
- [SchedMD@2445294e2](https://github.com/SchedMD/slurm/commit/2445294e2c45b55bf4ba3294025e4d280e26679b)
- [SchedMD@ed22dd0b3](https://github.com/SchedMD/slurm/commit/ed22dd0b3329b8a18323fdd2144f7f7b87df24b6)
- [SchedMD@5f2849cc0](https://github.com/SchedMD/slurm/commit/5f2849cc01b021732f2c85bba0853a435adb364a)
- [SchedMD@20d04daa6](https://github.com/SchedMD/slurm/commit/20d04daa6a49eef6db3024c05a7c29abf87ce642)
- [SchedMD@b17a78268](https://github.com/SchedMD/slurm/commit/b17a78268f944b97019b7d88b95adbe7cbf3857c)
- [SchedMD@7b1eeaaa0](https://github.com/SchedMD/slurm/commit/7b1eeaaa01bb322014749462c186840d11c732e1)
- [SchedMD@2d0c866a5](https://github.com/SchedMD/slurm/commit/2d0c866a5027eda0a9889c10566e696d9c4d80d1)
- [SchedMD@37727a036](https://github.com/SchedMD/slurm/commit/37727a036acd9ec624fde6a208706bd3fb37145a)
- [SchedMD@176cc0695](https://github.com/SchedMD/slurm/commit/176cc06952e0fb189aac5fdf1620fe59be8f2153)
- [SchedMD@ff8649de4](https://github.com/SchedMD/slurm/commit/ff8649de4c47847901777701069278850e24787d)
- [SchedMD@939757023](https://github.com/SchedMD/slurm/commit/9397570237e1c03264a8a4fb0f61e4a63940ea20)
- [SchedMD@6d6e9dd46](https://github.com/SchedMD/slurm/commit/6d6e9dd46408f4ffe08a83b6f95befd504b6afe1)
- [SchedMD@4789d3ed9](https://github.com/SchedMD/slurm/commit/4789d3ed965d8be41584e7ac4d71c0aea2049f1a)
- [SchedMD@a4032004a](https://github.com/SchedMD/slurm/commit/a4032004aa39d2a2b33ab47c5a1e017f08725be6)
- [SchedMD@e91c0e9ff](https://github.com/SchedMD/slurm/commit/e91c0e9ff9e6763b73c4dfef0826868f4776f695)
- [SchedMD@dea4559da](https://github.com/SchedMD/slurm/commit/dea4559daf1b15f681f1d17c3c6dc29fcafb8eb1)
- [SchedMD@7a4ccba84](https://github.com/SchedMD/slurm/commit/7a4ccba844e60d3cc807b8acecafa64a82f22795)
- [SchedMD@f640818f9](https://github.com/SchedMD/slurm/commit/f640818f9f20bd3275894c632c35326fbf4125c6)
- [SchedMD@caca697d7](https://github.com/SchedMD/slurm/commit/caca697d74f582b3ffb706d33bbb6f0ec15a7a14)
- [SchedMD@cb5a93d4b](https://github.com/SchedMD/slurm/commit/cb5a93d4b70f6f60a27a7f829093c32c225ae2e1)
- [SchedMD@0799f5374](https://github.com/SchedMD/slurm/commit/0799f5374d94950063d99ac1ddfd6f8c7556ce60)
- [SchedMD@119db302e](https://github.com/SchedMD/slurm/commit/119db302ebb2e9899c3b0238fd3f2d92895e1827)
- [SchedMD@03e231884](https://github.com/SchedMD/slurm/commit/03e2318845ce4180ee6b2269b68d74e2defbffc2)
- [SchedMD@3777c85b4](https://github.com/SchedMD/slurm/commit/3777c85b468b02e47887901461d51e69733a86cd)

This patch can be removed once Slurm 25.05 has been released.

### 0012-25.05-fix-ping-race-condition.patch

This patch is a backport from the upcoming 25.05 release that should hopefully address the
recurrent issue we've seen with a mass drain of nodes. The issue stems from the periodic pings
that slurmctld sends out to nodes that havent reported in a while. If a ping cycle takes too long
and a new ping cycle is started, this can trigger unchecked nodes to be marked as DOWN which can
trigger subsequent job interruptions/cancellations.
[Slurm Commit](https://github.com/SchedMD/slurm/commit/f5541fc35d013337c4ccc50306d47f77406f710b)
ref: SUNK-809

This patch can be removed once Slurm 25.05 has been released.

### 0013-fix-node-reg-mem-percent-parsing.patch

This patch is a backport from the upcoming 25.05 release that should address the node reg mem
percent parsing issue we've seen with `Low Memory` drains despite having the node reg mem percent set
to 95% eventually draining the nodes and putting them into an invalid state.
[Slurm Commit](https://github.com/SchedMD/slurm/commit/69966c2f88bcd213015a617ae16a8d3a54aa9e3e)
ref: SUNK-932

This patch can be removed once Slurm 25.05 has been released.

### 0014-25.05-fix-xcpuinfo-core-count.patch

This patch fixes a bug in the `xcpuinfo.xcpuinfo_get_cpuspec` function that incorrectly calculates the
number of cores on the machine - it misses the inclusion of sockets.
ref: [SchedMD 22797](https://support.schedmd.com/show_bug.cgi?id=22797)

### 0015-remove-gres-core-range-matches-sock.patch

This is reverting a change that was first introduced in the following commit:
[Slurm Commit](https://github.com/SchedMD/slurm/commit/b886b6e82fc5194e057488027a29d201c10846bb)

When we have the previous 0011-25.05-container-fixes patch applied, the newly constrained node will never
be allowed to join the cluster because the gres core range will never match the socket count.

### 0016-scontrol-dashboards

This patch adds node and job Grafana dashboard URLs to the outputs of `scontrol show node` and
`scontrol show job`. It also prints the job dashboard URL in interactive srun sessions, slurmd logs,
and sbatch log files when a job launches or terminates. The base URLs for this can be configured in
the `slurm.conf` keys `SUNKNodeDashboardURL` and `SUNKJobDashboardURL`.

### 0018-backport_prolog_fixes

This patch backports the following commits to address an issue with prolog scripts not being
executed correctly.
[Slurm Commit 1](https://github.com/SchedMD/slurm/commit/d4d020b553c3c510a80c2e60b6063bd52e78414c)
[Slurm Commit 2](https://github.com/SchedMD/slurm/commit/6df8fb6ecf2a0d9f9bca0d9670efcc67ac943d3b)

### 0019-empty-pids-retry

This patch changes the `_empty_pids()` function of the cgroup/v2 plugin to retry PID migration and
the enabling of subtree controllers on failure. This gets around a known issue caused by PIDs
entering the top-level cgroup during migration, resulting in failures to enable controllers in that
location due to the [no internal process constraint].

This patch will still be required as of [5a1c0174] because the race condition still exists in
`_empty_pids()`.

The race condition is described in the [source code].

[5a1c0174]: https://github.com/SchedMD/slurm/commit/5a1c017420123f0978a559788723749be043e2c8
[source code]: https://github.com/SchedMD/slurm/blob/slurm-24-11-5-1/src/plugins/cgroup/v2/cgroup_v2.c#L1387-L1394
[no internal process constraint]: https://docs.kernel.org/admin-guide/cgroup-v2.html#no-internal-process-constraint
>>>>>>> e364bad (fix: Backport slurmctld segfault patch):images/patches/slurm/README.md
