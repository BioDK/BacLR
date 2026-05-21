# Dataset

The raw sequencing reads are **not committed to this repository**. Long-read
FASTQ files are large, and raw data belongs in a data archive, not in git. The
`data/raw/` directory is git-ignored. This file records which dataset to use
and how to obtain it.

## Dataset in use

| Field | Value |
|---|---|
| Organism | *Bacillus subtilis* strain MB9_B6 |
| Sequencing technology | Oxford Nanopore MinION (long-read, WGS) |
| Approximate genome size | ~4.2 Mb (`genome_size: "4.2m"` in `config/config.yaml`) |
| Source | ENA (European Nucleotide Archive) |
| BioProject | PRJNA587401 |
| Experiment | SRX7091076 |
| Run accession | SRR10390699 |
| Subset used | first 100,000 reads |
| Local file | `data/raw/bsubtilis_MB9_B6_ONT_100k.fastq.gz` |

### Why this dataset

*Bacillus subtilis* is a small, well-characterised single-chromosome bacterium
on the project's preferred-organism list. The 100,000-read subset is ~675 Mb of
sequence, giving roughly 160x coverage of the ~4.2 Mb genome — comfortably
enough for a confident long-read assembly while still small enough to download
and assemble within a one-day sprint.

### Read statistics (100k-read subset)

| Metric | Value |
|---|---|
| Reads | 100,000 |
| Total bases | ~675 Mb |
| Mean read length | ~6,750 bp |
| Maximum read length | ~109 kb |
| Estimated coverage | ~160x (genome ~4.2 Mb) |

## Selection criteria

For a one-day project the dataset is chosen to be **small and fast**, not
biologically perfect:

1. **Small bacterial isolate** - a single-chromosome bacterium, genome roughly
   2-6 Mb. Candidate organisms: *Escherichia coli*, *Lactococcus lactis*,
   *Lactiplantibacillus plantarum*, *Bacillus subtilis*.
2. **Modest read volume** - enough for solid coverage (~50-100x) but small
   enough to download quickly and assemble on a laptop in minutes to an hour.
   At 50-100x for a ~4 Mb genome that is roughly 200-400 Mb of reads.
3. **A real bacterial isolate**, not a metagenome or a mixed sample - the
   pipeline assumes one organism.
4. **Public and openly accessible** via SRA or ENA.

Any small bacterial isolate that meets these criteria works. *Escherichia
coli* and *Bacillus subtilis* are well-documented choices with many public ONT
datasets, so they are safe picks for a fast, reliable run.

## How to download

A download script is provided:
[`download_Bacillus_OxfordNanoporeMinION_ena_demo.sh`](download_Bacillus_OxfordNanoporeMinION_ena_demo.sh).
Run it from the repository root:

```bash
bash data/download_Bacillus_OxfordNanoporeMinION_ena_demo.sh
```

The script queries ENA for run `SRR10390699`, streams the gzipped FASTQ, keeps
the first 100,000 reads, and writes the result to
`data/raw/bsubtilis_MB9_B6_ONT_100k.fastq.gz` — the path `config/config.yaml`
points at. ENA serves gzipped FASTQ over plain HTTP, so no SRA Toolkit is
needed. Download logs go to `data/logs/` (git-ignored).

The raw FASTQ (~672 MB) is **not committed** — `data/raw/` is git-ignored.
Each person runs the download script once on their own machine.

After downloading, confirm the workflow is pointed at the file: `raw_reads:` in
`config/config.yaml` should read
`data/raw/bsubtilis_MB9_B6_ONT_100k.fastq.gz` and `genome_size:` should be
`4.2m`.

## Limitations

- A small dataset chosen for speed may give lower coverage or a slightly more
  fragmented assembly than a deeply sequenced one. That is an acceptable
  trade-off for a one-day learning project and is noted honestly in the report.
- The dataset is FASTQ only. It supports assembly, QC, and annotation but
  **not** the methylation module, which needs raw-signal (POD5/FAST5) data -
  see [`docs/methylation_design.md`](../docs/methylation_design.md).
