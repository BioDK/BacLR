# Workflow overview

This document gives the bird's-eye view of the pipeline: what runs, in what
order, and what each step hands to the next. For the *why* behind each tool,
see [tool_principles.md](tool_principles.md).

## The pipeline at a glance

```
   data/raw/sample.fastq.gz   (raw Oxford Nanopore reads)
            │
            ├──────────────▶  nanoplot_raw      → read QC plots + NanoStats.txt
            │
            ▼
       filter_reads (chopper) → results/filtered_reads/sample.filtered.fastq.gz
            │
            ▼
      assemble_flye (Flye)    → results/assembly/flye/assembly.fasta
            │
            ├──────────────▶  quast_qc (QUAST)  → results/qc/quast/report.tsv
            │                        │
            ├──────────────▶  annotate_prokka   → results/annotation/prokka/sample.gff
            │                        │
            │                        ▼
            │                 summarize_results → results/summary/summary_table.tsv
            │
            ├╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶  checkm2_qc        → completeness/contamination   [extended]
            ├╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶  bakta_annotate    → richer functional annotation [extended]
            ├╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶  gtdbtk_classify   → standardised taxonomy        [documented]
            └╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶  nanomotif         → methylation motifs           [documented]

   ── solid arrows: core pipeline, runs on a laptop
   ╌╌ dashed arrows: optional modules, gated by flags in config/config.yaml
```

## Tiers

The pipeline is deliberately split into three tiers so the core is always
runnable while the heavier tools are honestly accounted for.

| Tier | Rules | Status |
|---|---|---|
| **Core** | `nanoplot_raw`, `filter_reads`, `assemble_flye`, `quast_qc`, `annotate_prokka`, `summarize_results` | Runs end-to-end on a laptop. |
| **Extended** | `checkm2_qc`, `bakta_annotate` | Real rules. Each needs a ~3 GB database. Enable in config when installed. |
| **Documented** | `gtdbtk_classify`, `nanomotif_methylation` | Real rules, but need a ~110 GB database / raw-signal data. Kept disabled; explained in the docs. |

## Step summary

| Step | Tool | Input | Output | What it tells you |
|---|---|---|---|---|
| Read QC | NanoPlot | raw FASTQ | NanoStats + plots | Read length, quality, yield |
| Filtering | chopper | raw FASTQ | filtered FASTQ | Cleaner reads for assembly |
| Assembly | Flye | filtered FASTQ | assembly.fasta | The reconstructed genome |
| Assembly QC | QUAST | assembly.fasta | report.tsv | Contigs, N50, length, GC% |
| Annotation | Prokka | assembly.fasta | GFF + protein FASTA | Genes, rRNA, tRNA, functions |
| Summary | Python | QUAST + GFF | summary_table.tsv | One-glance run summary |
| Completeness | CheckM2 | assembly.fasta | quality_report.tsv | Completeness, contamination |
| Rich annotation | Bakta | assembly.fasta | GFF3 | Standardised functional annotation |
| Taxonomy | GTDB-Tk | assembly.fasta | summary.tsv | Standardised species classification |
| Methylation | NanoMotif | assembly + modkit pileup | motifs.tsv | Methylated sequence motifs |

## Running it

```bash
# 1. Dry run - prints the plan, runs nothing. Always do this first.
snakemake -n

# 2. Real run - one conda environment created per rule.
snakemake --use-conda --cores 8

# 3. Visualise the dependency graph.
snakemake --dag | dot -Tsvg > dag.svg
```

To enable an optional module, set its flag (e.g. `run_checkm: true`) in
`config/config.yaml` and make sure its database is in place. The `Snakefile`
adds the corresponding target only when the flag is on.

## Design choices worth knowing

- **chopper instead of NanoFilt.** The job ad names NanoFilt; chopper is its
  maintained successor (same author, same purpose, faster). Both are installed
  so they can be compared. See [tool_principles.md](tool_principles.md).
- **CheckM2 instead of CheckM.** CheckM2 is more accurate and far easier to
  install (no `pplacer` dependency).
- **Per-rule conda environments.** Each rule declares its own `envs/*.yaml`, so
  every step runs with documented, pinned software - the basis of
  reproducibility.
- **Methylation is documented, not faked.** NanoMotif needs raw-signal data,
  not the FASTQ used for assembly. The rule and a mock output are provided; see
  [methylation_design.md](methylation_design.md).
