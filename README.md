# BacLR

**Long-read bacterial genome reconstruction & methylation-aware annotation**

A reproducible [Snakemake](https://snakemake.readthedocs.io/) workflow that
takes raw Oxford Nanopore long reads from a bacterial isolate and reconstructs,
quality-controls, and annotates its genome — with a documented
methylation-aware extension.

It is both a working pipeline and a learning resource: every step is explained
in [`docs/`](docs/), so you can understand the *why* behind each tool, not just
run commands.

---

## What it does

```
raw ONT reads ──▶ read QC ──▶ filtering ──▶ assembly ──▶ assembly QC ──┐
                                                       └▶ annotation ──┴▶ summary
```

| Step | Tool | Output |
|------|------|--------|
| Read QC | NanoPlot | Read-length & quality summary |
| Filtering | chopper | Cleaned reads |
| Assembly | Flye | Reconstructed genome (FASTA) |
| Assembly QC | QUAST | Contigs, N50, length, GC% |
| Annotation | Prokka | Genes, rRNA, tRNA, functions |
| Summary | Python | One-file QC + annotation table |

**Optional modules** (configurable, off by default):

- **CheckM2** — genome completeness and contamination
- **Bakta** — richer functional annotation
- **GTDB-Tk** — standardised taxonomic classification
- **NanoMotif** — methylation motif discovery

The workflow has been run end-to-end on a public *Bacillus subtilis* Oxford
Nanopore dataset, reconstructing the genome as a single circular chromosome.
See [`report/mini_report.md`](report/mini_report.md) for the full results.

## Why long reads

Long-read sequencing makes it possible to reconstruct a bacterial genome as a
single contiguous, often circular chromosome — short reads break apart at
repeats. And because Nanopore measures raw electrical signal, it can detect DNA
methylation directly, without extra chemistry. An accurate genome is the
prerequisite for everything else: methylation only becomes meaningful once it
can be placed in the context of an assembled, annotated genome.

## Quick start

```bash
# 1. Clone
git clone https://github.com/BioDK/BacLR.git
cd BacLR

# 2. Set up conda environments and download data
#    -> follow docs/setup_tutorial.md (covers Intel & Apple Silicon Macs)

# 3. Dry-run (prints the plan, runs nothing)
conda activate baclr-snakemake
snakemake -n

# 4. Run the pipeline
snakemake --use-conda --cores 8 --conda-frontend conda
```

New to the project? **Start with [`docs/setup_tutorial.md`](docs/setup_tutorial.md)** —
it walks through conda setup, the dataset download, and the first run
step by step, with separate tracks for Intel and Apple Silicon Macs.

## Repository layout

```
BacLR/
├── README.md
├── Snakefile                   # the workflow definition
├── config/config.yaml          # all tunable parameters
├── envs/                       # one conda environment per workflow stage
├── data/
│   ├── README.md               # dataset source & download (raw data git-ignored)
│   └── download_*.sh           # dataset download script
├── docs/
│   ├── setup_tutorial.md       # set up the project on a new machine
│   ├── running_and_testing.md  # how to run, test, and troubleshoot
│   ├── workflow_overview.md    # bird's-eye view of the pipeline
│   ├── tool_principles.md      # what every tool does and why
│   └── methylation_design.md   # design of the methylation module
├── scripts/                    # helper scripts (summary table)
├── results/                    # workflow outputs (git-ignored)
│   └── methylation/example_output/   # mock NanoMotif output + format guide
└── report/mini_report.md       # results write-up
```

## Outputs

Results are organised per sample under `results/<stage>/{sample}/...`, so
multiple samples never collide. `{sample}` is the `sample` value in
[`config/config.yaml`](config/config.yaml).

| Output | Meaning |
|--------|---------|
| `results/qc/{sample}/nanoplot_raw/` | Read-length and quality summary of the raw reads |
| `results/filtered_reads/{sample}.filtered.fastq.gz` | Reads after quality/length filtering |
| `results/assembly/{sample}/flye/assembly.fasta` | The reconstructed genome |
| `results/assembly/{sample}/flye/assembly_info.txt` | Per-contig length, coverage, circular yes/no |
| `results/qc/{sample}/quast/report.tsv` | Assembly metrics: contigs, N50, length, GC% |
| `results/annotation/{sample}/prokka/` | Predicted genes, rRNA, tRNA, functional annotation |
| `results/summary/{sample}/summary_table.tsv` | One-glance summary merging QC and annotation |
| `results/qc/{sample}/checkm2/` | Completeness and contamination *(optional module)* |
| `results/taxonomy/{sample}/gtdbtk/` | Taxonomic classification *(optional module)* |

How to interpret these numbers is explained in
[`docs/tool_principles.md`](docs/tool_principles.md).

## Documentation

| Document | Read it for |
|----------|-------------|
| [`docs/setup_tutorial.md`](docs/setup_tutorial.md) | Setting up the project on a new machine — **start here** |
| [`docs/running_and_testing.md`](docs/running_and_testing.md) | Running the pipeline, testing it, and troubleshooting |
| [`docs/workflow_overview.md`](docs/workflow_overview.md) | The pipeline at a glance |
| [`docs/tool_principles.md`](docs/tool_principles.md) | What every tool does, why, and how to read its output |
| [`docs/methylation_design.md`](docs/methylation_design.md) | Design and data requirements of the methylation module |
| [`report/mini_report.md`](report/mini_report.md) | Results of the completed pipeline run |

## Design notes

- **chopper instead of NanoFilt** — chopper is the maintained successor (same
  author, same job, faster). NanoFilt still works and is installed alongside.
- **CheckM2 instead of CheckM** — CheckM2 is more accurate and far easier to
  install (no `pplacer` dependency).
- **One conda environment per workflow stage** — each rule declares its own
  environment file in `envs/`, so every step runs with documented software.
  Some tools cannot share an environment (Python-version conflicts), which is
  why there are several small environments rather than one large one.
- **Methylation is documented, not faked.** NanoMotif needs
  modification-aware basecalled data (a modBAM with `MM`/`ML` tags), not the
  plain FASTQ used for assembly. The repository provides the Snakemake rule, a
  full design document ([`docs/methylation_design.md`](docs/methylation_design.md)),
  and a clearly labelled mock output — rather than fabricating a result the
  input data cannot support.
