# Example methylation output (MOCK DATA)

> **This is mock data, not a real result.**
> The file `motifs.tsv` in this folder was hand-written to illustrate the
> *format* a NanoMotif run produces. No methylation analysis was run in this
> project, because doing so requires raw-signal (POD5/FAST5) sequencing data
> rather than the FASTQ data used for assembly. See
> [`docs/methylation_design.md`](../../../docs/methylation_design.md) for the
> full explanation and the real pipeline.

## Why this folder exists

The methylation module cannot honestly be run on a FASTQ-only dataset (it
needs raw-signal data — see the design document). Rather than leave the module
empty or fake a result, this folder shows exactly what a real output looks
like and how to read it. That makes the intended analysis fully specified and
reproducible for anyone who has the right input data.

## Reading `motifs.tsv`

| Column | Meaning |
|---|---|
| `contig` | Assembled contig the motif was found on |
| `motif` | Sequence pattern; ambiguity codes allowed (W = A/T, N = any) |
| `mod_type` | Modification type: `6mA`, `4mC`, or `5mC` |
| `mod_position` | 0-based index of the methylated base within the motif |
| `n_motif` | Number of occurrences of the motif in the genome |
| `n_modified` | Number of those occurrences found methylated |
| `methylation_degree` | `n_modified / n_motif` (fraction methylated) |

## How to interpret the mock example

- **`GATC` (6mA), degree 0.994** - methylated at almost every occurrence
  genome-wide. This is the classic Dam-methyltransferase signal in many
  bacteria: a strong, confident, near-complete methylation signature.
- **`CCWGG` (5mC), degree 0.970** - another strong genome-wide motif (the
  pattern recognised by Dcm-type methyltransferases).
- **`GANTC` (6mA), degree 0.965** - a third active motif; `N` means any base at
  that position.
- **`GCGGCCGC` (4mC), degree 0.627** - a longer, rarer motif methylated only
  partially. Partial methylation can indicate a less active methyltransferase,
  a recently acquired R-M system, or competition with another DNA-binding
  process. It is a more nuanced signal than the near-100% motifs.
- **`GATC` on `contig_2`** - the same motif appears on a second contig (e.g. a
  plasmid) and is also methylated, showing the methyltransferase acts
  genome-wide, not just on the chromosome.

A real interpretation would then overlay these motif positions on the genome
annotation to ask *where* the methylation falls - in promoters, coding regions,
or regulatory elements - which is the step that connects methylation to
phenotype.
