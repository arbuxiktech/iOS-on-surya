# Surya initial launchd catalog wait

Hardware photos from the 0261 kernel stop at `HFS catalog lookup begin
[launchd]`; `/sbin` lookup completes. Changing only `ufswait=0` produces the
same stop. This weakens a UFS timed-sleep-specific explanation, but does not
exclude a failed read, incorrect data, or a filesystem wait. Root mounting
alone does not establish that all storage reads work.

Patch 0262 extends `sweetinittrace=1` with PID 1 checkpoints for catalog key
construction/allocation, BTSearchRecord hint and tree searches, node reads,
buffer reads and extent searches. UFS read checkpoints show partition-relative
byte offset, request size, mutex acquisition, command completion and strategy
return. A successful read also reports FNV-1a over its first min(size, 4096)
bytes before buffer unmapping. Writes are not traced, avoiding feedback from
the persistent console logger. The shared trace is capped at 512 lines and
remains off by default. No read/write policy, retries, locking order or
filesystem return values are changed. Timing can change with tracing enabled.

A read-only audit of the local `ios18-root-full-surya.simg` validates the
catalog index route as well as the leaf records. The catalog has seven inline
extents, depth 4, and 8192-byte nodes. Expected release launchd route:

| Node | Raw image / userdata byte offset | First 4096 bytes FNV-1a |
| --- | ---: | --- |
| 23911 | 13661687808 | ffe3711e |
| 23910 | 13661679616 | de0a0c3b |
| 25350 | 15715041280 | 8b3e0fe8 |
| 25234 | 15714091008 | 5d3126db |

These values describe the local image, not verified phone contents. Only
compare a checksum when the read starts at the listed offset and covers at
least 4096 bytes; larger/merged requests can start elsewhere. HFS swaps B-tree
nodes after reads, so compare the UFS raw-data checksum rather than swapped
memory. A cached node need not produce a UFS request. The node number printed
on `BT node release` is the next child, already selected by the original code.

The next RAM-boot diagnostic uses normal UFS wait defaults, matching the
0261 baseline. Photograph the last numbered checkpoints. A `read begin`
without `read done` points inside the UFS command; `BT buffer read begin`
without a UFS request may instead indicate buffer-cache/block-mapping work.
Completed reads followed by a search stall require examining that search and
its data. No new root flash is required for this diagnostic.
