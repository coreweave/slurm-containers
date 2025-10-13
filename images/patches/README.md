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


### 0020-25.05.3-topology-null-seg-fault

This patch fixes a critical NULL pointer dereference bug in Slurm 25.05.3's topology handling that causes `slurmd` to segfault during dynamic node registration when topology is not configured.

`slurmd -Z --conf 'Feature=...'` crashes with segmentation fault during initialization.

This patch adds a NULL check at the beginning of `topology_p_get_node_addr()` to gracefully handle the case where topology is not configured, returning `SLURM_SUCCESS`. This addresses issues with both tree and block topologies.

This patch can be removed once SchedMD fixes the bug in a future release (25.05.3+).
