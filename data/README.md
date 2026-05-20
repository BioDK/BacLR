# Dataset

The raw sequencing reads are **not committed to this repository**. Long-read
FASTQ files are large, and raw data belongs in a data archive, not in git. The
`data/raw/` directory is git-ignored. This file records which dataset to use
and how to obtain it.

## Dataset to use

> **Status: to be finalised.**
> The exact accession is selected in the run session. The criteria below
> explain how it is chosen; fill in the chosen accession when known.

| Field | Value |
|---|---|
| Organism | _to be filled in_ |
| Sequencing technology | Oxford Nanopore (long-read) |
| Approximate genome size | _to be filled in_ (set `genome_size` in `config/config.yaml`) |
| Source | NCBI SRA / ENA |
| Accession | _to be filled in_ |

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

A fermentation-relevant organism such as *Lactococcus lactis* ties the project
most directly to the EpiFerm context; *E. coli* is the safest choice for a
guaranteed fast, well-documented run. Either is fine.

## How to download

Once an accession is chosen, download with the SRA Toolkit:

```bash
mkdir -p data/raw

# Replace SRRXXXXXXX with the chosen accession.
prefetch SRRXXXXXXX
fasterq-dump SRRXXXXXXX --outdir data/raw

# Compress and name it to match config/config.yaml (raw_reads:).
gzip data/raw/SRRXXXXXXX.fastq
mv data/raw/SRRXXXXXXX.fastq.gz data/raw/sample.fastq.gz
```

Or download the FASTQ directly from ENA (often simpler - ENA serves gzipped
FASTQ over plain HTTP/FTP, no toolkit needed):

```bash
mkdir -p data/raw
# Get the FASTQ URL from the ENA record for the accession, then:
wget -O data/raw/sample.fastq.gz "<ENA_FASTQ_URL>"
```

After downloading, point the workflow at the file by checking that
`raw_reads:` in `config/config.yaml` matches `data/raw/sample.fastq.gz`, and set
`genome_size:` to the organism's approximate genome size.

## Limitations

- A small dataset chosen for speed may give lower coverage or a slightly more
  fragmented assembly than a deeply sequenced one. That is an acceptable
  trade-off for a one-day learning project and is noted honestly in the report.
- The dataset is FASTQ only. It supports assembly, QC, and annotation but
  **not** the methylation module, which needs raw-signal (POD5/FAST5) data -
  see [`docs/methylation_design.md`](../docs/methylation_design.md).
