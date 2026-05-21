# Methylation-aware extension: design and data requirements

This document describes the methylation module honestly. The short version:
**methylation analysis cannot be run from the FASTQ data this pipeline uses for
assembly.** It needs a different kind of input. Rather than pretend otherwise,
this repository includes the Snakemake rule, this design document, and a
clearly-labelled mock output so the intended workflow is fully specified and
reproducible by anyone who has the right data.

---

## 1. Why plain FASTQ is not enough

A FASTQ file stores, per read, the base calls (A/C/G/T) and a per-base quality
score. It does **not** store whether a base is methylated.

DNA methylation - in bacteria most often 6-methyladenine (6mA),
4-methylcytosine (4mC), or 5-methylcytosine (5mC) - is a chemical modification
of a base. Detecting it requires looking at the *raw sequencing signal*, not
the final base calls.

Nanopore sequencing measures the electrical current as DNA passes through a
pore. A methylated base disturbs that current differently from its unmodified
form. Modern basecallers can be run in a *modification-aware* mode that, in
addition to calling the base, estimates the probability that the base is
methylated. That extra information is stored as `MM` and `ML` tags inside a BAM
file (a "modBAM"). Plain FASTQ has no place to put it.

So: **the assembly branch of this pipeline uses FASTQ; the methylation branch
needs raw signal (POD5/FAST5) re-basecalled into a modBAM.**

---

## 2. The real methylation pipeline

```
   raw signal                modification-aware            aligned
   POD5 / FAST5   ───────▶    basecalling (Dorado)  ───▶   modBAM
                                                            │
                              (MM / ML modification tags)   │
                                                            ▼
   assembly.fasta  ──────────────────────────────▶   align modBAM to assembly
   (from the Flye branch)                                    │
                                                             ▼
                                                   modkit pileup
                                                   (per-position methylation)
                                                             │
                                                             ▼
                                                   NanoMotif motif discovery
                                                             │
                                                             ▼
                                              motifs.tsv  (methylated motifs)
```

**Step by step:**

1. **POD5 / FAST5** - the raw current-signal files written by the ONT device.
   These are large and are not usually published alongside small FASTQ-only
   datasets.

2. **Modification-aware basecalling (Dorado).** Dorado is ONT's basecaller.
   Run with a methylation-capable model, it produces a BAM whose reads carry
   `MM`/`ML` tags - the per-base modification probabilities.
   ```bash
   dorado basecaller sup,5mCG_5hmCG,6mA pod5_dir/ > calls.bam
   # the model string after "sup" requests modified-base calling
   ```

3. **Align the modBAM to the assembly.** The modification calls have to be
   placed on the reconstructed genome so methylation can be summarised per
   genomic position. Dorado can align directly, or use minimap2 while keeping
   the modification tags.

4. **`modkit pileup`.** modkit (also from ONT) collapses the per-read
   modification calls into a per-position table: at each genomic coordinate,
   how many reads were methylated versus not.
   ```bash
   modkit pileup aligned.modBAM results/methylation/modkit_pileup.bed \
       --ref results/assembly/flye/assembly.fasta
   ```

5. **NanoMotif motif discovery.** NanoMotif takes the assembly plus the modkit
   pileup and searches for short sequence patterns (motifs) that are methylated
   far more consistently than chance. Those motifs are the methylation
   "signature" of the strain.
   ```bash
   nanomotif motif_discovery results/assembly/flye/assembly.fasta \
       results/methylation/modkit_pileup.bed \
       --out results/methylation/nanomotif
   ```

The `nanomotif_methylation` rule in the `Snakefile` encodes the final step. It
is disabled by default (`run_nanomotif: false`) because steps 1-4 need data
this project does not download.

---

## 3. What you would need to actually run this

| Requirement | Notes |
|---|---|
| Raw POD5 (or FAST5) signal data | Large; rarely published with small isolate datasets |
| Dorado basecaller + a modification-aware model | Free from ONT; GPU strongly recommended |
| modkit | ONT tool, available via conda/bioconda |
| NanoMotif | In `envs/annotation.yaml` |
| The assembly | Produced by the core pipeline - this part is fine |

The realistic ways to obtain suitable data:

- Find a public dataset that *explicitly* provides POD5/FAST5 raw signal (some
  ONT reference and benchmarking datasets do).
- Use a dataset that already provides a modification-aware **modBAM**, skipping
  the basecalling step.
- In a lab setting, generate the data yourself - you control basecalling and
  would simply choose a methylation-aware model.

---

## 4. Worked example of the output format

A real NanoMotif `motifs.tsv` looks similar to the mock file in
[`results/methylation/example_output/`](../results/methylation/example_output/).
The columns are:

| Column | Meaning |
|---|---|
| `contig` | Which assembled contig the motif was found on |
| `motif` | The sequence pattern, with the methylated position marked |
| `mod_type` | Modification type: `6mA`, `4mC`, or `5mC` |
| `mod_position` | Index of the methylated base within the motif |
| `n_motif` | How many times the motif occurs in the genome |
| `n_modified` | How many of those occurrences are methylated |
| `methylation_degree` | Fraction methylated (`n_modified / n_motif`) |

A motif with a high `methylation_degree` (close to 1.0) across many genomic
occurrences is a confident, genome-wide methylation signal - typically the
recognition site of an active methyltransferase.

---

## 5. Why methylation analysis matters

Bacterial DNA methylation is biologically important in several ways, and the
methylation module connects the pipeline to each of them:

- **Restriction-modification (R-M) systems.** Most bacterial methylation motifs
  are the recognition sites of R-M systems. Annotation (Prokka/Bakta) flags the
  methyltransferase genes; NanoMotif finds the motifs they act on. Together they
  link an enzyme in the genome to a methylation pattern in the DNA.

- **Strain discrimination.** Two strains can be nearly identical in DNA sequence
  yet carry different methylation motifs. Methylation profiling adds a layer of
  strain-level resolution that sequence alone misses.

- **Phenotype links.** Methylation can influence gene regulation and replication
  timing. Differences in methylation between strains are candidate explanations
  for differences in observable behaviour.

- **Genomic context.** Overlaying methylation motifs on the annotation shows
  whether methylation sits in promoters, coding regions, or regulatory elements
  - the step that turns a methylation pattern into a biological interpretation.

Being explicit that this needs raw-signal data, and specifying exactly which
data and steps, keeps the methylation module honest: it documents the real
requirement rather than producing a result the input data cannot support.
