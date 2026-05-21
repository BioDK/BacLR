# Mini-report: long-read bacterial genome reconstruction

A compact write-up of a long-read bacterial genome analysis run, built as
hands-on preparation for the EpiFerm Research Assistant position at UCPH FOOD.

---

## 1. Aim

To build and run a reproducible long-read bacterial genome analysis workflow,
and in doing so gain hands-on familiarity with the toolchain used for
long-read bacterial genome reconstruction and methylation-aware annotation -
the kind of workflow central to the EpiFerm project at UCPH FOOD.

The workflow takes raw Oxford Nanopore reads from a bacterial isolate and runs
read filtering, de novo assembly, assembly QC, genome annotation, and a
summary, with documented optional modules for completeness assessment,
taxonomy, and methylation motif discovery.

## 2. Dataset

- **Organism:** *Bacillus subtilis* strain MB9_B6
- **Sequencing technology:** Oxford Nanopore MinION (long-read, whole-genome)
- **Accession / source:** ENA run SRR10390699 (BioProject PRJNA587401),
  first 100,000 reads
- **Approximate genome size:** ~4.2 Mb
- **Why chosen:** a small, well-characterised single-chromosome bacterium on
  the project's preferred-organism list. The 100,000-read subset (~675 Mb) is
  small enough to download and assemble within a one-day sprint while still
  giving deep coverage. See [`data/README.md`](../data/README.md) for selection
  criteria and the download script.

## 3. Workflow overview

The pipeline is implemented in Snakemake. Core steps (run on a laptop):

1. **Read QC** - NanoPlot summary of the raw reads.
2. **Filtering** - chopper removes short and low-quality reads.
3. **Assembly** - Flye reconstructs the genome de novo.
4. **Assembly QC** - QUAST reports contigs, N50, length, GC%.
5. **Annotation** - Prokka predicts genes, rRNA, tRNA, and functions.
6. **Summary** - a Python script merges QC and annotation into one table.

Each rule runs in its own conda environment. Optional modules (CheckM2, Bakta,
GTDB-Tk, NanoMotif) are gated by flags in `config/config.yaml`. See
[`docs/workflow_overview.md`](../docs/workflow_overview.md).

The run reported here completed all six core steps end-to-end.

### Read filtering

Of the 100,000 raw reads, chopper kept **65,857** (quality cutoff Q10, minimum
length 1,000 bp), retaining ~568 Mb of sequence. The raw reads had a mean
quality of Q11.4 and a read-length N50 of 17.4 kb; 83% of reads were above
Q10. Removing the short and low-quality tail left a clean, high-coverage set
for assembly.

## 4. Assembly results

| Metric | Value |
|---|---|
| Number of contigs | 2 |
| Total length (bp) | 4,087,131 |
| Largest contig (bp) | 4,082,166 |
| N50 (bp) | 4,082,166 |
| GC content (%) | 43.88 |
| Circular contig(s) | contig_2 (the chromosome) |

Flye reconstructed the genome as **two contigs**:

- **contig_2 - 4,082,166 bp, circular, 142x coverage.** This is the complete
  *Bacillus subtilis* chromosome, recovered as a single circular molecule -
  the ideal outcome for a long-read bacterial assembly.
- **contig_3 - 4,965 bp, 237x coverage**, flagged by Flye as a repeat element.
  Its short length and high coverage are consistent with a small extrachromosomal
  element or a high-copy repeat rather than part of the main chromosome.

## 5. QC interpretation

The QUAST numbers indicate a high-quality assembly:

- **Contig count (2)** is very low, as expected for a single-chromosome
  bacterium. The assembly is not fragmented.
- **Total length (4.09 Mb)** is close to the expected ~4.2 Mb for
  *B. subtilis*. The small shortfall is normal for an unpolished long-read
  assembly and for the use of a 100k-read subset rather than the full run.
- **N50 (4.08 Mb)** equals the chromosome length - the assembly is concentrated
  in one long contig, which is the strongest possible signal of contiguity.
- **GC content (43.88%)** matches the *B. subtilis* reference (~43.5%), a good
  sign that the assembly is the expected organism and free of obvious
  contamination.
- **Coverage:** the ~568 Mb of filtered reads over a ~4.2 Mb genome gives
  roughly 135x coverage (Flye's own estimate), comfortably above the depth
  needed for a confident assembly.

## 6. Annotation results

| Feature | Count |
|---|---|
| CDS | 6,770 |
| tRNA | 86 |
| rRNA | 33 |
| tmRNA | 1 |

The tRNA count (86) and rRNA count (33, i.e. roughly ten rRNA operons) are in
the expected range for a *B. subtilis*-sized genome, and the single tmRNA is
as expected.

The CDS count (6,770) is **higher than the ~4,200 protein-coding genes** in
*B. subtilis* reference genomes. This is a known effect of annotating an
**unpolished long-read assembly**: residual indel errors introduce spurious
frameshifts, which causes gene callers to split one real gene into several
shorter predicted ORFs. The fix is an assembly polishing step before
annotation (see Limitations and Next steps). The inflated count is reported
honestly here rather than glossed over - it is a feature of the input data,
not of the organism.

## 7. Taxonomy / completeness results

The completeness/contamination (CheckM2) and taxonomy (GTDB-Tk) modules were
**not run** in this sprint. CheckM2 needs a ~3 GB database and GTDB-Tk a
~110 GB database; setting these up was out of scope for the one-day run. The
Snakemake rules and conda environments for both are in place, so they can be
enabled (`run_checkm`, `run_gtdbtk` in `config/config.yaml`) once the databases
are available. See [`docs/tool_principles.md`](../docs/tool_principles.md) for
what each would tell us - in short, CheckM2 would confirm the genome is
complete and uncontaminated, and GTDB-Tk would formally confirm the organism
is *B. subtilis*. The QC evidence already gathered (GC%, genome size, single
circular chromosome) is consistent with a complete, correct *B. subtilis*
genome.

## 8. Methylation-aware extension

No methylation analysis was run in this project. Methylation detection requires
modification-aware basecalled data (raw POD5/FAST5 signal re-basecalled into a
modBAM with MM/ML tags), whereas the dataset used here is FASTQ only.

The methylation module is therefore **fully designed and documented** rather
than executed: the `nanomotif_methylation` Snakemake rule is in place, the
required data and exact pipeline (Dorado -> modkit -> NanoMotif) are described
in [`docs/methylation_design.md`](../docs/methylation_design.md), and a mock
output illustrating the result format is in
[`results/methylation/example_output/`](../results/methylation/example_output/).

This is a deliberate honesty choice - documenting the real requirement rather
than fabricating a result the input data cannot support.

## 9. Relevance to EpiFerm

This project mirrors core tasks of the EpiFerm Research Assistant role:
reconstructing a bacterial genome from Oxford Nanopore reads, evaluating
assembly quality, annotating genomic features, and framing a methylation-aware
extension. These steps are the foundation for linking bacterial genome
structure and methylation profiles to strain-level phenotypes such as
fermentation performance. Building the workflow in Snakemake, with per-rule
conda environments, also directly exercises the reproducible-workflow skills
the position asks for.

## 10. Limitations

- A 100,000-read subset was used for speed; the full run would give slightly
  more complete coverage.
- **No polishing step was applied after assembly.** This is the most likely
  cause of the inflated CDS count (section 6); adding a polishing step (e.g.
  Medaka) would correct residual indels and bring the gene count closer to the
  expected ~4,200.
- CheckM2, Bakta, and GTDB-Tk were not run - their databases were out of scope
  for the one-day window. The rules and environments are in place.
- The methylation module was documented, not executed, because the dataset
  lacks the required raw-signal data (see section 8).
- Software versions in the conda environments are not strictly pinned (a few
  lower bounds are set where needed for compatibility).

## 11. Next steps

- Add an assembly **polishing step** (Medaka) before annotation, and re-check
  the CDS count.
- Run the extended tier (CheckM2 for completeness/contamination, Bakta for
  richer annotation) and GTDB-Tk for taxonomy, with their databases in place.
- Obtain a dataset with raw POD5 signal and run the full methylation pipeline
  end-to-end (Dorado modified-base basecalling -> modkit -> NanoMotif).
- Pin exact software versions for stricter reproducibility, and add tests for
  the helper scripts.

---

## Appendix: run environment

- Pipeline run on macOS (Apple Silicon) with conda environments built as
  `osx-64` under Rosetta 2.
- Tool versions: Flye 2.9.6, QUAST 5.3.0, Prokka 1.15.6, chopper 0.11.0,
  NanoPlot 1.46.2, Snakemake 9.5.1.
- Full workflow and setup instructions: [`../README.md`](../README.md) and
  [`../docs/setup_tutorial.md`](../docs/setup_tutorial.md).
