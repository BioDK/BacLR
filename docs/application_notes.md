# Application notes

Material for connecting this project to the Research Assistant in
Bioinformatics position on the EpiFerm project at the Department of Food
Science, University of Copenhagen. The framing throughout is honest: this is
*hands-on preparation* that demonstrates motivation and the ability to learn a
new toolchain quickly - not a claim of prior expertise.

---

## CV bullet

> Built a Snakemake-based long-read bacterial genome analysis workflow using
> Oxford Nanopore data, including read filtering, Flye assembly, QUAST-based
> assembly QC, genome annotation, and a documented methylation-aware NanoMotif
> extension.

A shorter variant:

> Developed a reproducible Snakemake pipeline for long-read bacterial genome
> reconstruction (read filtering, Flye assembly, QC, annotation) with a
> documented methylation-analysis module.

---

## Cover letter sentence

> To strengthen my preparation for this role, I recently built a compact
> Snakemake-based long-read bacterial genome analysis workflow using Oxford
> Nanopore data, covering read filtering, bacterial genome assembly, assembly
> QC, annotation, and a methylation-aware extension.

---

## Interview talking points

Short, honest answers. They are starting points - say them in your own words.

### 1. What is long-read sequencing useful for?

Long reads (Oxford Nanopore, tens of kilobases) span repetitive regions that
short reads cannot. For bacterial genomes that means an assembly often comes
out as a single contiguous, sometimes circular chromosome instead of many
fragments. Long reads also preserve the raw electrical signal, which lets you
detect DNA modifications such as methylation directly - without extra chemistry
like bisulfite treatment. Both properties matter for EpiFerm: contiguous
genomes plus native methylation detection.

### 2. Why use Flye for bacterial genome assembly?

Flye is a long-read de novo assembler that handles ONT data well and is
straightforward to run. It builds an internal repeat graph, resolves repeats
using read length, and reports whether contigs are circular - useful because
bacterial chromosomes and plasmids are typically circular. For a small
bacterial isolate it produces a high-quality assembly on a laptop in minutes to
an hour.

### 3. What does QUAST tell you?

QUAST reports the basic quality numbers for an assembly: number of contigs,
total length, N50, and GC content. You read them against expectations for the
organism - ideally one long contig near the expected genome size, a large N50,
and the expected GC%. QUAST is the QC gate that decides whether an assembly is
trustworthy enough to annotate and interpret.

### 4. What does CheckM (CheckM2) tell you?

CheckM2 estimates two things: completeness (how much of the genome is present)
and contamination (how much foreign or duplicated sequence is mixed in). It
works from gene content - a machine-learning model in CheckM2's case. A common
bar for a high-quality bacterial genome is completeness above ~95% and
contamination below ~5%. It is the evidence that an assembly is complete and
clean before you make any biological claims about it.

### 5. What is the role of methylation analysis in bacterial epigenetics?

Bacteria methylate specific DNA motifs - usually producing 6mA, 4mC, or 5mC.
Methylation underlies restriction-modification systems (defence against foreign
DNA), affects replication timing, and can regulate gene expression. Strains
that are nearly identical in DNA sequence can differ in methylation, and that
difference can affect phenotype. For EpiFerm, methylation profiling is a way to
link genome and epigenome to strain-level traits such as fermentation
performance. The key technical point: methylation detection needs
modification-aware basecalled data (a modBAM with MM/ML tags), not plain FASTQ.

### 6. What did you learn from building this project?

Several things. How a long-read bacterial genome workflow fits together from
raw reads to annotated genome. How to express that as a reproducible Snakemake
pipeline with per-rule conda environments. And - importantly - the real data
requirements of methylation analysis: I learned that NanoMotif needs raw-signal
data, so I designed and documented the methylation module honestly rather than
forcing a result the input data could not support.

### 7. What would you improve with more time?

Run the full extended tier - CheckM2 and Bakta with their databases, and
GTDB-Tk for taxonomy. Obtain a dataset with raw POD5 signal so the methylation
module runs end-to-end through Dorado modified-base basecalling, modkit, and
NanoMotif. Add a polishing step after assembly, add automated tests for the
helper scripts, and pin exact software versions in the conda environments for
stricter reproducibility.

---

## Honest framing - read before the interview

- This is a learning and preparation project. Describe it as such. It shows you
  can pick up an unfamiliar toolchain quickly and that you understand
  reproducible-workflow practice.
- Do not overstate. You have built and understood the workflow; you have not
  (yet) run every tool at production scale.
- The methylation module being *documented rather than executed* is a strength,
  not a gap, when explained well: it shows you understood the real data
  requirement and chose honesty over a fabricated result. That judgement is
  exactly what a research role values.
