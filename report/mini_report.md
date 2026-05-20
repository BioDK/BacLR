# Mini-report: long-read bacterial genome reconstruction

> **Status: template.** The results sections below are filled in after the
> pipeline has been run on the chosen dataset. Placeholders are marked
> `[ ... ]`. Sections describing method and rationale are already complete.

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

- **Organism:** [ to be filled in ]
- **Sequencing technology:** Oxford Nanopore long reads
- **Accession / source:** [ SRA/ENA accession ]
- **Approximate genome size:** [ ... Mb ]
- **Why chosen:** a small, fast bacterial isolate suitable for a one-day run.
  See [`data/README.md`](../data/README.md) for selection criteria and
  download commands.

## 3. Workflow overview

The pipeline is implemented in Snakemake. Core steps (run on a laptop):

1. **Read QC** - NanoPlot summary of the raw reads.
2. **Filtering** - chopper removes short and low-quality reads.
3. **Assembly** - Flye reconstructs the genome de novo.
4. **Assembly QC** - QUAST reports contigs, N50, length, GC%.
5. **Annotation** - Prokka predicts genes, rRNA, tRNA, and functions.
6. **Summary** - a Python script merges QC and annotation into one table.

Optional modules (CheckM2, Bakta, GTDB-Tk, NanoMotif) are gated by flags in
`config/config.yaml`. See [`docs/workflow_overview.md`](../docs/workflow_overview.md).

## 4. Assembly results

| Metric | Value |
|---|---|
| Number of contigs | [ ... ] |
| Total length (bp) | [ ... ] |
| Largest contig (bp) | [ ... ] |
| N50 (bp) | [ ... ] |
| GC content (%) | [ ... ] |
| Circular contig(s) | [ from assembly_info.txt ] |

[ One or two sentences: did the assembly come out as a single circular
chromosome near the expected genome size? Any plasmids? ]

## 5. QC interpretation

[ Interpret the QUAST numbers against expectations for the organism. Is the
contig count low? Is total length close to the expected genome size? Is N50
large (i.e. the assembly concentrated in long contigs)? Is GC% as expected?
What does coverage - total filtered bases / genome size - work out to? ]

## 6. Annotation results

| Feature | Count |
|---|---|
| CDS | [ ... ] |
| tRNA | [ ... ] |
| rRNA | [ ... ] |
| tmRNA | [ ... ] |

[ Are the feature counts in the expected range for a bacterium of this size
(a few thousand CDS, dozens of tRNAs, a few rRNA operons)? Note anything
interesting - e.g. genes related to restriction-modification systems or to
fermentation-relevant metabolism. ]

## 7. Taxonomy / completeness results (if available)

[ If CheckM2 was run: completeness % and contamination %, and whether they
meet the high-quality bar (completeness > ~95%, contamination < ~5%). If
GTDB-Tk was run: the assigned classification and whether it matches the
expected organism. If neither was run, state that and refer to
`docs/tool_principles.md` for how they would be applied. ]

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

- A small dataset was chosen for speed; deeper sequencing could give a more
  contiguous assembly.
- No polishing step was applied after assembly.
- CheckM2 / Bakta / GTDB-Tk were [ run / not run - state which ] depending on
  database availability within the one-day window.
- The methylation module was documented, not executed, because the dataset
  lacks the required raw-signal data (see section 8).
- Software versions in the conda environments are not strictly pinned.

## 11. Next steps

- Run the extended tier (CheckM2, Bakta) and GTDB-Tk taxonomy with their
  databases in place.
- Obtain a dataset with raw POD5 signal and run the full methylation pipeline
  end-to-end (Dorado modified-base basecalling -> modkit -> NanoMotif).
- Add an assembly polishing step.
- Pin exact software versions for stricter reproducibility, and add tests for
  the helper scripts.
