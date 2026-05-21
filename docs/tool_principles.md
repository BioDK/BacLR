# Tool principles

This document explains the *why* behind each step of the pipeline, not just the
commands. Each section follows the same structure: what the tool does, why it
is used here, what input it expects, what output it produces, how to read the
result, and why it matters in the workflow.

If you want to understand how the pipeline works rather than just run it, this
is the document to read.

---

## Background: long-read sequencing in one paragraph

Oxford Nanopore (ONT) sequencing reads DNA by pulling a single strand through a
protein pore and measuring tiny changes in electrical current. Each base (and
each *modified* base) perturbs the current in a characteristic way. Two things
follow from this. First, reads are *long* - often tens of kilobases - because
there is no need to chop the DNA into short fragments. Second, the raw signal
carries information about base modifications such as methylation, because a
methylated base disturbs the current differently from an unmethylated one. Both
properties matter for this pipeline: long reads make bacterial genome
reconstruction much easier, and the methylation signal is what the optional
methylation module is built to analyse.

---

## chopper (read filtering; replaces NanoFilt)

**What a FASTQ file contains.** A FASTQ file stores sequencing reads. Each read
has four lines: an identifier, the DNA sequence, a separator, and a *quality
string*. The quality string has one character per base, encoding a Phred
quality score - an estimate of how likely that base call is wrong.

**What quality scores mean.** Phred Q is `-10 * log10(P_error)`. Q10 means a 1
in 10 chance the base is wrong (~90% accuracy); Q20 is 1 in 100 (99%). ONT
reads are noisier than Illumina, so a per-read mean quality around Q10-Q15 is
normal for older chemistry and Q15+ for modern high-accuracy basecalling.

**What the tool does.** chopper scans every read and discards those whose mean
quality or length fall below a cutoff. It is the maintained successor to
NanoFilt - same author, same purpose, written in Rust so it is faster. chopper
is what the tool's own authors now recommend; both chopper and NanoFilt are
installed in `envs/filtering.yaml` so you can compare them.

**Why long-read data needs filtering.** A small number of very short or very
low-quality reads add noise without adding useful information. Removing them
gives the assembler a cleaner picture. But filtering is a trade-off: long-read
assembly depends on having enough *coverage* (reads spanning each position).
Over-aggressive filtering throws away coverage and can fragment the assembly.
The goal is to remove obvious junk, not to chase the highest possible average
quality.

**Input:** raw FASTQ (gzipped). **Output:** filtered FASTQ (gzipped).

**How to read the result.** Compare read counts and the NanoPlot summary
before and after filtering. You want to have removed a modest fraction (often
well under 20%) and retained enough total bases for good coverage. A useful
rule of thumb: total filtered bases divided by genome size should give at least
~30-50x coverage for a confident bacterial assembly.

**Why it matters.** Clean input is the foundation. Every downstream
conclusion about genome structure or methylation rests on the reads, so being
deliberate about filtering is a basic reproducibility and quality habit.

---

## NanoPlot (read QC visualisation)

**What it does.** NanoPlot summarises a set of reads: read-length distribution,
quality distribution, total yield, N50 of read lengths. It is QC for the
*reads*, separate from QUAST which is QC for the *assembly*.

**Why it is used here.** Looking at the raw reads before assembly tells you
what you are working with - how long the reads are, how good they are, how much
data you have - and therefore how aggressively you can filter.

**Input:** FASTQ. **Output:** an HTML report plus a `NanoStats.txt` summary.

**How to read it.** Check median read length (longer is better for assembly),
median quality, and total bases (for coverage). A long tail of very short reads
is normal and is what filtering trims.

**Why it matters.** A quick, honest look at data quality before committing
compute is exactly the habit a reproducible-workflow role expects.

---

## Flye (long-read de novo assembly)

**What "de novo assembly" means.** "De novo" means reconstructing the genome
from the reads alone, without aligning to a reference. The assembler finds
overlaps between reads and stitches them into longer contiguous sequences.

**Short-read vs long-read assembly.** Short reads (Illumina, ~150 bp) are
accurate but too short to span repetitive regions, so short-read assemblies
break into many fragments wherever a repeat is longer than a read. Long reads
(ONT, tens of kb) span most bacterial repeats, so the assembly is far more
contiguous - often a bacterial chromosome comes out as a single piece. The
cost is higher per-base error, which is corrected during assembly and, if
needed, by polishing.

**What contigs are.** A *contig* is a contiguous stretch of assembled sequence.
Fewer, longer contigs means a more complete reconstruction.

**Circular bacterial chromosomes.** Most bacteria have a single circular
chromosome, sometimes plus circular plasmids. Flye detects circularity and
reports it in `assembly_info.txt`. A circular contig at roughly the expected
genome size is a strong sign of a complete chromosome.

**Assembly graph, briefly.** Internally Flye builds a *repeat graph*: nodes are
unique sequences, edges are repeats. The graph captures the ambiguity that
repeats create. The final contigs are paths through this graph. You do not need
the graph to use the assembly, but it explains why repeats are the hard part.

**Why bacterial genomes suit this workflow.** They are small (typically 2-6
Mb), usually a single chromosome, and have modest repeat content. A laptop can
assemble one in minutes to an hour - ideal for a one-day project.

**Input:** filtered FASTQ. **Output:** a directory containing `assembly.fasta`
(the sequence), `assembly_info.txt` (per-contig length, coverage, circular
yes/no), and an assembly graph.

**How to read the result.** Open `assembly_info.txt`. Ideally one long contig
near the expected genome size, marked circular, with even coverage. Many short
contigs or a total length far from expected is a warning sign.

**Why it matters.** This is the genome-reconstruction step at the heart of the
pipeline. A contiguous, accurate assembly is the prerequisite for everything
after it - you cannot map methylation onto genome structure you have not
reconstructed.

---

## QUAST (assembly quality control)

**Why assembly QC is needed.** An assembler always produces *an* answer. QUAST
gives you the numbers to judge whether that answer is good.

**Key metrics.**
- **Number of contigs** - how fragmented the assembly is. For a single-
  chromosome bacterium, low (ideally 1, plus any plasmids) is good.
- **Total length** - should be close to the expected genome size. Much larger
  can mean contamination or uncollapsed duplication; much smaller means the
  assembly is incomplete.
- **N50** - the contig length such that half of the assembly sits in contigs at
  least that long. A large N50 means the assembly is concentrated in long
  pieces. For a complete bacterial chromosome the N50 is essentially the
  chromosome length.
- **GC content** - the percentage of G and C bases. It is species-characteristic
  (e.g. *E. coli* ~50%, many lactic acid bacteria ~35-40%). A GC% far from the
  expected value, or a bimodal GC across contigs, hints at contamination.

**Input:** `assembly.fasta`. **Output:** `report.tsv`/`report.html` with the
metrics above.

**How to read it.** Compare every number against the expectation for your
organism. The pattern you want: contig count low, total length on target, N50
large, GC% as expected.

**Why QC matters before methylation.** Methylation motifs are inferred from how
reads behave at specific sequence contexts across the genome. If the assembly
is wrong - misjoined, contaminated, fragmented - methylation calls inherit
those errors. Good assembly QC protects every downstream conclusion.

**Why it matters.** QUAST is the explicit, documented QC gate between assembly
and interpretation - it is what tells you whether an assembly is good enough to
annotate and build on.

---

## CheckM2 (genome completeness & contamination)

**What completeness means.** The fraction of the genome that is actually
present in the assembly. 100% means nothing expected is missing.

**What contamination means.** The fraction of the assembly that does not belong
to the target organism - sequence from another species, or duplicated content.

**How marker genes estimate quality.** Certain genes occur in (almost) every
bacterium in a known copy number - often exactly once. CheckM's logic: count
those marker genes. Missing markers imply missing genome (low completeness);
markers present in extra copies imply foreign or duplicated sequence (high
contamination). CheckM2 improves on the original CheckM by using a machine-
learning model over gene content rather than fixed marker sets, which makes it
more accurate and far easier to install - no `pplacer` dependency. CheckM2 is
the modern equivalent of the original CheckM and is what this pipeline uses.

**Input:** `assembly.fasta` plus a ~3 GB CheckM2 database. **Output:**
`quality_report.tsv` with a completeness and a contamination percentage.

**How to read it.** A common quality bar for a "high-quality" bacterial genome
is completeness > 95% and contamination < 5%. Higher completeness and lower
contamination is better.

**Database setup.**
```bash
checkm2 database --download --path db/checkm2
```

**Why it matters.** Before claiming anything about a strain's genome or its
methylation, you must know the genome is complete and clean. CheckM2 is the
evidence for that claim.

---

## GTDB-Tk (taxonomic classification) - documented only

**Why taxonomy assignment matters.** After assembling a genome you should
confirm *what organism it is*. This catches sample swaps and contamination, and
it is required to interpret results in the right biological context.

**What GTDB is.** The Genome Taxonomy Database is a standardised bacterial and
archaeal taxonomy built from genome data rather than historical names. It gives
every genome a consistent, reproducible classification.

**Why standardised taxonomy is useful.** Traditional names are inconsistent and
sometimes contradict genomic relatedness. A genome-based standard means two
researchers classifying the same assembly get the same answer.

**How it confirms identity.** GTDB-Tk places your assembly in a reference tree
and compares it to known genomes. If you sequenced what you think you did, the
classification matches the expected species.

**Why it is documented-only here.** GTDB-Tk needs a ~110 GB reference database.
That download and disk footprint are out of scope for a one-day laptop project.
The Snakemake rule (`gtdbtk_classify`) and environment file are included so the
step is reproducible wherever the database exists.

**How it would be run.**
```bash
# Download the database (~110 GB), then point GTDB-Tk at it:
export GTDBTK_DATA_PATH=db/gtdbtk
gtdbtk classify_wf --genome_dir results/assembly/flye \
    --out_dir results/taxonomy/gtdbtk --extension fasta --cpus 8
```
Set `run_gtdbtk: true` in `config/config.yaml` once the database is in place.

**Why it matters.** Strain identity is the anchor for strain-level work.
Knowing exactly which organism (and ideally which strain) you have is what lets
you connect a genome and its methylation profile to an observed phenotype.

---

## Prokka / Bakta (genome annotation)

**What genome annotation means.** Assembly gives you the DNA sequence. Annotation
identifies the *features* in it - where the genes are and what they probably do.

**Feature types.**
- **CDS** (coding sequence) - a stretch predicted to encode a protein.
- **rRNA** - genes for ribosomal RNA (the 5S, 16S, 23S components).
- **tRNA** - genes for transfer RNAs that bring amino acids during translation.
- **Functional annotation** - a putative function attached to each CDS, assigned
  by comparing the predicted protein to databases of known proteins.

**Prokka vs Bakta.** Both annotate bacterial genomes. Prokka is fast and has
been a community standard for years; this pipeline uses it as the core
annotator. Bakta is newer, gives more standardised and detailed functional
annotation, and is included as an extended module using its *light* database
(~3 GB unpacked, versus ~30 GB for the full DB).

**Input:** `assembly.fasta`. **Output:** a GFF file (features with coordinates),
a FASTA of predicted proteins, and a text summary of feature counts.

**How to read the result.** Check the feature counts in the summary. For a
typical few-Mb bacterium, expect on the order of a few thousand CDS, a few rRNA
operons, and dozens of tRNAs. Counts far outside that range suggest an assembly
problem upstream.

**Why annotation matters for methylation.** A methylation motif on its own is
just a short sequence pattern. Annotation puts it in context: is the motif
inside a gene promoter, in a coding region, near a regulatory element? That
context is what turns "this motif is methylated" into a biological statement.

**Restriction-modification systems.** Annotation can flag
restriction-modification (R-M) systems - the methyltransferase/endonuclease
pairs that are the usual *source* of bacterial methylation motifs. It can also
flag genes tied to specific metabolic functions (carbohydrate metabolism,
proteolysis, stress response), which is what makes the annotation biologically
useful.

**Why it matters.** Annotation is the bridge between raw genome structure and
biological interpretation. It is what lets you say a methylation motif sits in a
functionally meaningful place, and it identifies the R-M systems that explain
where the methylation comes from.

---

## NanoMotif (methylation motif discovery)

This section is a short overview. The full data requirements, the exact
preprocessing pipeline, and a worked example of the output are in
[methylation_design.md](methylation_design.md) - read that document for the
real detail.

**What bacterial DNA methylation is.** Bacteria chemically modify specific
bases in their DNA, most commonly producing 6-methyladenine (6mA),
4-methylcytosine (4mC), or 5-methylcytosine (5mC). These modifications occur at
specific short sequence patterns - *motifs* - recognised by methyltransferase
enzymes.

**Why Nanopore can detect modifications.** Because sequencing measures
electrical current, and a methylated base disturbs the current differently from
an unmethylated one, the modification can be called directly from the signal -
no separate chemistry (no bisulfite treatment) required.

**What a methylation motif is.** A short, often palindromic sequence pattern
that an organism methylates consistently - for example a particular adenine
within `GATC`. NanoMotif scans methylation calls across the genome and finds
the patterns that are methylated far more often than chance.

**Why methylation matters.** In bacteria, methylation is the basis of
restriction-modification systems (defence against foreign DNA), influences the
timing of DNA replication, and can regulate gene expression. Strains that look
nearly identical at the DNA-sequence level can differ in their methylation
patterns, and that difference can affect phenotype.

**Why plain FASTQ is not enough.** This is the key technical point. A standard
FASTQ file contains base calls and quality scores but *not* modification
information. Detecting methylation requires modification-aware basecalling: the
raw signal (POD5/FAST5) must be re-basecalled in a mode that emits per-base
modification probabilities, producing a BAM with `MM`/`ML` tags. NanoMotif works
from that, not from FASTQ. See [methylation_design.md](methylation_design.md).

**Input:** the assembly plus a per-position methylation pileup derived from
modification-aware basecalled reads. **Output:** a table of discovered motifs
with their modification type and methylation degree.

**Why it is documented-only here.** Most small public ONT datasets ship FASTQ,
not the POD5/modBAM data NanoMotif needs. Rather than fake this step, the
repository includes the rule, the design document, and a clearly-labelled mock
output showing the format. This is honest and it demonstrates understanding of
the real pipeline.

**Why it matters.** Methylation profiling is what connects an assembled genome
to its epigenetic layer. Understanding *exactly* what data and steps it
requires - and being candid that plain FASTQ does not suffice - is more
valuable than producing a result from data that cannot support it.

---

## Snakemake (workflow management)

**What workflow management means.** Instead of running each tool by hand, you
describe the pipeline as a set of *rules*. Each rule declares its inputs,
outputs, and command. Snakemake reads these declarations, works out the
dependency graph, and runs the steps in the correct order.

**Why reproducibility matters.** A bioinformatics result is only trustworthy if
someone else - or you, months later - can reproduce it. Workflow managers make
the entire analysis explicit, version-controllable, and re-runnable with a
single command.

**Core concepts.**
- **Rule** - one step of the pipeline (e.g. `assemble_flye`).
- **Input / output** - the files a rule consumes and produces. Snakemake links
  rules by matching one rule's output to another's input.
- **Wildcards** - placeholders like `{sample}` that let one rule apply to many
  samples without duplicating code.
- **Config** - external settings (in `config/config.yaml`) kept separate from
  the workflow logic, so re-running with new parameters is a one-line change.
- **Environments** - each rule can declare a conda environment (`envs/*.yaml`),
  so every step runs with pinned, documented software versions.

**Why it beats running commands by hand.** Snakemake runs only what is needed
(if the assembly already exists, it will not rebuild it), parallelises
independent steps, fails loudly when a step fails, and records exactly what was
done. Manual command sequences are easy to get wrong, hard to resume after a
failure, and leave no record.

**Why it matters.** Expressing this pipeline as a Snakemake workflow - with
per-rule conda environments and a separate config - is what makes the whole
analysis reproducible: one command re-runs it, and the exact tools and settings
used are recorded in the repository.
