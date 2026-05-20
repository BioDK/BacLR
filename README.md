# BacLR — long-read bacterial genome reconstruction & methylation-aware annotation

A reproducible Snakemake workflow that takes raw Oxford Nanopore long reads
from a bacterial isolate and reconstructs, quality-controls, and annotates its
genome, with a documented methylation-aware extension.

The project was built as hands-on preparation for the **Research Assistant in
Bioinformatics** position on the **EpiFerm** project at the Department of Food
Science, University of Copenhagen. It is both a working mini-pipeline and a
learning resource — every step is explained in [`docs/`](docs/).

---

## What this project does

Starting from raw Oxford Nanopore reads, the pipeline:

1. **Inspects read quality** — NanoPlot
2. **Filters reads** — chopper (the maintained successor to NanoFilt)
3. **Reconstructs the genome** — Flye long-read de novo assembly
4. **Quality-controls the assembly** — QUAST
5. **Annotates genomic features** — Prokka (genes, rRNA, tRNA, functions)
6. **Produces a summary table** — a single file merging QC and annotation

Optional, configurable modules extend this:

- **CheckM2** — genome completeness and contamination
- **Bakta** — richer functional annotation (light database)
- **GTDB-Tk** — standardised taxonomic classification *(documented)*
- **NanoMotif** — methylation motif discovery *(documented)*

## Why it matters

Long-read sequencing makes it possible to reconstruct a bacterial genome as a
single contiguous, often circular chromosome, and — because Nanopore measures
raw electrical signal — to detect DNA methylation directly. Reconstructing the
genome accurately is the prerequisite for everything else: you cannot interpret
methylation in genomic context without first having the genome and its
annotation. This workflow covers that foundation and specifies, honestly, what
the methylation step additionally requires.

## How it connects to long-read bacterial genome reconstruction

Steps 2–5 are exactly the reconstruction-and-QC chain: filter the reads,
assemble them de novo with a long-read assembler, and verify the result with
assembly QC and (optionally) a completeness check. The output is an annotated,
quality-controlled bacterial genome.

## How it connects to methylation-aware analysis

Bacterial methylation occurs at specific sequence motifs and underlies
restriction-modification systems, replication timing, and gene regulation. The
methylation module (NanoMotif) discovers those motifs. Crucially, methylation
detection needs **modification-aware basecalled data** (a modBAM with `MM`/`ML`
tags), not the plain FASTQ used for assembly. Rather than fake this step, the
repository provides the Snakemake rule, a full design document
([`docs/methylation_design.md`](docs/methylation_design.md)), and a clearly
labelled mock output. Annotation links any discovered motif to its genomic
context — the step that turns a methylation pattern into a biological
statement.

## Repository layout

```
BacLR/
├── README.md
├── Snakefile                 # the workflow
├── config/config.yaml        # all tunable parameters
├── envs/                     # one conda environment per workflow stage
├── data/README.md            # dataset source & download (raw data git-ignored)
├── docs/
│   ├── workflow_overview.md   # bird's-eye view of the pipeline
│   ├── tool_principles.md     # what every tool does and why (teaching doc)
│   ├── methylation_design.md  # honest design of the methylation module
│   └── application_notes.md   # CV/cover-letter/interview material
├── results/                  # workflow outputs (git-ignored, except the
│   └── methylation/example_output/   # mock NanoMotif output + format guide
├── scripts/                  # helper scripts for the summary table
└── report/mini_report.md     # results write-up
```

## Quick start

### 1. Prerequisites

[Conda / Mamba](https://github.com/conda-forge/miniforge) and Snakemake:

```bash
conda install -n base -c conda-forge -c bioconda snakemake-minimal
```

> **Apple Silicon note.** Some Bioconda packages lack native ARM builds. If an
> environment fails to solve, create conda environments under `osx-64`
> emulation (`CONDA_SUBDIR=osx-64`) or use the Docker route. This does not
> affect Intel macOS or Linux.

### 2. Get a dataset

Choose a small public Oxford Nanopore bacterial isolate dataset and download it
into `data/raw/`. See [`data/README.md`](data/README.md) for selection criteria
and download commands. Then set `raw_reads`, `sample`, and `genome_size` in
[`config/config.yaml`](config/config.yaml).

### 3. Dry-run the workflow

```bash
snakemake -n
```

This prints the execution plan without running anything — always do this first.

### 4. Run it

```bash
snakemake --use-conda --cores 8
```

Snakemake creates one conda environment per rule and runs the core pipeline.
To enable an optional module, set its flag (e.g. `run_checkm: true`) in
`config/config.yaml` and make sure its database is in place.

## What each output means

Result files are organised per sample under a `{sample}/` subfolder (the
`sample` value in `config/config.yaml`), so several samples can be processed
without their outputs colliding. The paths below use `{sample}` as a
placeholder.

| Output | Meaning |
|---|---|
| `results/qc/{sample}/nanoplot_raw/` | Read-length and quality summary of the raw reads |
| `results/filtered_reads/{sample}.filtered.fastq.gz` | Reads after quality/length filtering |
| `results/assembly/{sample}/flye/assembly.fasta` | The reconstructed genome |
| `results/assembly/{sample}/flye/assembly_info.txt` | Per-contig length, coverage, circular yes/no |
| `results/qc/{sample}/quast/report.tsv` | Assembly metrics: contigs, N50, length, GC% |
| `results/annotation/{sample}/prokka/` | Predicted genes, rRNA, tRNA, functional annotation |
| `results/summary/{sample}/summary_table.tsv` | One-glance summary merging QC and annotation |
| `results/qc/{sample}/checkm2/` | Completeness and contamination *(if enabled)* |
| `results/taxonomy/{sample}/gtdbtk/` | Taxonomic classification *(if enabled)* |
| `results/methylation/example_output/` | Mock NanoMotif output illustrating the format |

How to interpret these numbers is explained in
[`docs/tool_principles.md`](docs/tool_principles.md).

## Documentation

- [`docs/setup_tutorial.md`](docs/setup_tutorial.md) — step-by-step setup on a new machine (start here)
- [`docs/workflow_overview.md`](docs/workflow_overview.md) — the pipeline at a glance
- [`docs/tool_principles.md`](docs/tool_principles.md) — what every tool does, why, and how to read its output
- [`docs/methylation_design.md`](docs/methylation_design.md) — design and data requirements of the methylation module
- [`docs/application_notes.md`](docs/application_notes.md) — CV, cover-letter and interview material
- [`report/mini_report.md`](report/mini_report.md) — results write-up

## Relevance to the EpiFerm Research Assistant position

This project was created to gain practical experience with long-read bacterial
genome analysis workflows relevant to the EpiFerm project at UCPH FOOD. The
workflow reconstructs a bacterial genome from Oxford Nanopore reads, evaluates
assembly quality, annotates genomic features, and includes a methylation-aware
extension. These steps mirror core tasks involved in linking bacterial genome
structure and methylation profiles to strain-level phenotypes such as
fermentation performance.

## Honest scope

This is a learning and preparation project, built in a short, focused sprint.
The core pipeline (filtering, assembly, QC, annotation) runs end-to-end. The
extended modules need multi-gigabyte databases and are enabled when those are
available. The methylation module is documented and demonstrated with a mock
output rather than executed, because it requires raw-signal sequencing data
that the assembly dataset does not include — a deliberate choice to document
the real requirement rather than fabricate a result.
