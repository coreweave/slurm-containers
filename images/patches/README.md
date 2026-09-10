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

## 0008-job-skip-ids

This patch adds a `SlurmJobSkipIds` option to `slurm.conf` (a comma-separated list of job ids). When
`slurmctld` loads saved job state on startup, any job whose id matches an entry in the list is
deleted instead of being restored. This is useful when a job record becomes corrupted: on recovery,
`slurmctld` will fail to process the job and crash, which prevents the controller from starting and
blocks all scheduling. Skipping the offending job ids breaks the loop and allows `slurmctld` to
finish recovery and continue processing jobs.

If upstream was to correct the root cause of why job records become corrupted, or handle corrupted
job records gracefully, then this patch would no longer be required.

## 0009-sched-skip-held-job

Backport of SchedMD commit `d8c64b0188` (Ticket 22041), first released in 24.11.2 and never
backported to the 24.05 line. A job that can run in multiple partitions or QOS appears in the
scheduling queue once per partition/QOS. When an earlier attempt held the job (priority 0), later
queue entries for the same job were still processed, which could leave the job record in a bad state
with no `job_resrcs`. The patch skips a queued job whose priority is 0 (held from a failed attempt
in another partition/QOS), addressing one root cause of records with a NULL `job_resrcs`.

This patch is re-anchored for 24.05: the upstream hunk does not apply as-is because 24.05 nests the
block one level deeper and uses a different trailing comment.

## 0010-sync-nodes-null-resrcs

Backport of SchedMD commit `6407c8eb7c` (Ticket 22041), first released in 24.11.2 and never
backported to the 24.05 line. During state recovery, `_sync_nodes_to_active_job` copied
`job_ptr->job_resrcs->node_bitmap` unconditionally at the top of the function, which crashes
`slurmctld` when a recovered active job has a NULL `job_resrcs`. The patch defers the copy to the
node-resize path where it is actually consumed and guards it with a NULL check, logging an error
instead of dereferencing.

This is the upstream form of the fix. It applies cleanly to 24.05.
