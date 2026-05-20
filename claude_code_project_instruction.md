# Claude Code Project Instruction File

## Role

You are Claude Code acting as a pair-programming tutor and implementation assistant.

Your task is to help build a GitHub-ready project called:

**Long-read bacterial genome reconstruction and methylation-aware annotation pipeline**

The user is preparing for a Research Assistant in Bioinformatics job application at the Department of Food Science, University of Copenhagen, for the EpiFerm project. The job focuses on bacterial genome reconstruction, long-read sequencing data, methylation profiles, and reproducible bioinformatics workflows.

This project should be both:

1. A real working bioinformatics mini-project
2. A learning project that teaches the user the principles and mechanisms behind each step

Please do not only write code. Teach while building.

## Project background

The job ad mentions experience with:

- Long-read sequencing data
- Genome assembly
- Reconstruction of bacterial genomes
- Methylation profile interpretation
- Python, Bash, R
- Snakemake / Nextflow
- NanoFilt
- Flye
- Unicycler
- SPAdes
- MEGAHIT
- QUAST
- CheckM
- GTDB-Tk
- Bakta
- Prokka
- NanoMotif

The user does not currently have hands-on experience with many of these tools, so this project should help them quickly build practical familiarity.

The project should be achievable in one intense day by two people.

## High-level goal

Build a reproducible Snakemake workflow that takes a public bacterial Oxford Nanopore long-read dataset and performs:

1. Read filtering
2. Long-read genome assembly
3. Assembly quality control
4. Genome completeness/contamination assessment
5. Taxonomic classification
6. Genome annotation
7. Optional methylation motif analysis
8. Final mini-report

## Important teaching requirement

At each major step, explain:

1. What the tool does
2. Why it is used in this workflow
3. What input it expects
4. What output it produces
5. How to interpret the result
6. How this relates to the UCPH FOOD EpiFerm job

The user wants to understand the principles and mechanisms, not only run commands.

Use clear explanations and avoid unnecessary jargon.

## Suggested repository name

`epiferm-longread-bacterial-pipeline`

## Recommended folder structure

Create this structure:

```text
epiferm-longread-bacterial-pipeline/
├── README.md
├── Snakefile
├── config/
│   └── config.yaml
├── envs/
│   ├── filtering.yaml
│   ├── assembly.yaml
│   ├── qc.yaml
│   ├── annotation.yaml
│   └── taxonomy.yaml
├── data/
│   └── README.md
├── docs/
│   ├── workflow_overview.md
│   └── tool_principles.md
├── results/
│   ├── filtered_reads/
│   ├── assembly/
│   ├── qc/
│   ├── taxonomy/
│   ├── annotation/
│   └── methylation/
├── scripts/
│   ├── summarize_quast.py
│   └── make_summary_table.py
└── report/
    └── mini_report.md
```

## Implementation priorities

### Priority 1: Make a clean repository

Set up a readable, professional repository that looks good to a hiring manager or bioinformatics researcher.

The README should clearly explain:

- What the project does
- Why it matters
- How it connects to long-read bacterial genome reconstruction
- How it connects to methylation-aware analysis
- How to run the workflow
- What each output means

### Priority 2: Build a minimal working Snakemake workflow

Start with these rules:

1. `filter_reads`
2. `assemble_flye`
3. `quast_qc`
4. `annotate_prokka` or `annotate_bakta`
5. `summarize_results`

If time and installation allow, add:

6. `checkm_qc`
7. `gtdbtk_classify`
8. `nanomotif_methylation`

### Priority 3: Teach the concepts

Create `docs/tool_principles.md`.

For each tool, explain:

## NanoFilt

Teach:

- What FASTQ files contain
- Why read quality matters
- Why long-read data often needs filtering
- What quality scores mean
- Why filtering too aggressively can remove useful data
- How this relates to long-read bacterial assembly

## Flye

Teach:

- Why long-read assembly is useful
- The difference between short-read and long-read assembly
- What de novo genome assembly means
- Why bacterial genomes are suitable for this type of workflow
- What contigs are
- What circular bacterial chromosomes mean
- What assembly graph means at a high level

## QUAST

Teach:

- Why assembly QC is needed
- What N50 means
- What total assembly length means
- What number of contigs means
- What GC content means
- Why a high-quality assembly is important before methylation interpretation

## CheckM

Teach:

- What genome completeness means
- What contamination means
- How marker genes can be used to estimate genome quality
- Why completeness and contamination matter for bacterial genome reconstruction

## GTDB-Tk

Teach:

- Why taxonomy assignment matters
- What GTDB is
- Why standardized bacterial taxonomy is useful
- How taxonomy helps confirm whether the assembled genome matches the expected organism

## Bakta / Prokka

Teach:

- What genome annotation means
- What CDS, rRNA, tRNA, and functional annotation mean
- Why annotation is important for interpreting methylation in genomic context
- How annotation can identify restriction-modification systems and fermentation-relevant genes

## NanoMotif

Teach:

- What bacterial DNA methylation is
- Why Nanopore sequencing can detect DNA modifications
- What methylation motifs are
- Why methylation may affect strain behavior, gene regulation, or phenotype
- What input NanoMotif requires
- Why normal FASTQ files may not be enough for methylation analysis
- How methylation profiles connect to the EpiFerm project

## Snakemake

Teach:

- What workflow management means
- Why reproducibility matters
- What rules, inputs, outputs, wildcards, configs, and environments mean
- Why Snakemake is useful in bioinformatics projects
- How this improves over manually running commands

## Dataset selection

Help the user identify a small public Oxford Nanopore bacterial isolate dataset.

Preferred organism types:

- Lactiplantibacillus plantarum
- Lactococcus lactis
- Bacillus subtilis
- Escherichia coli
- Another small bacterial isolate with available ONT reads

For one day, prioritize a small, easy-to-run dataset over biological perfection.

Add a `data/README.md` file explaining:

- Dataset source
- Organism
- Sequencing technology
- Why this dataset was chosen
- Download command or accession number
- Any limitations

Do not commit large raw data files to GitHub. Add them to `.gitignore`.

## Snakemake requirements

Create a `config/config.yaml` like:

```yaml
sample: "sample"
raw_reads: "data/raw/sample.fastq.gz"
genome_size: "3m"
threads: 8
quality_cutoff: 10
min_length: 1000
run_checkm: false
run_gtdbtk: false
run_nanomotif: false
```

Create an initial `Snakefile` with clear comments.

The workflow should be understandable for a beginner.

Example rules to implement and improve:

```python
configfile: "config/config.yaml"

SAMPLE = config["sample"]

rule all:
    input:
        "results/assembly/flye/assembly.fasta",
        "results/qc/quast/report.tsv",
        "results/annotation/prokka/sample.gff",
        "results/summary/summary_table.tsv"

rule filter_reads:
    input:
        config["raw_reads"]
    output:
        "results/filtered_reads/{sample}.filtered.fastq"
    params:
        q=config["quality_cutoff"],
        l=config["min_length"]
    shell:
        "NanoFilt -q {params.q} -l {params.l} {input} > {output}"

rule assemble_flye:
    input:
        "results/filtered_reads/{sample}.filtered.fastq"
    output:
        "results/assembly/flye/assembly.fasta"
    params:
        outdir="results/assembly/flye",
        genome_size=config["genome_size"]
    threads:
        config["threads"]
    shell:
        "flye --nano-raw {input} --out-dir {params.outdir} --genome-size {params.genome_size} --threads {threads}"

rule quast_qc:
    input:
        "results/assembly/flye/assembly.fasta"
    output:
        "results/qc/quast/report.tsv"
    params:
        outdir="results/qc/quast"
    shell:
        "quast.py {input} -o {params.outdir}"

rule annotate_prokka:
    input:
        "results/assembly/flye/assembly.fasta"
    output:
        "results/annotation/prokka/sample.gff"
    params:
        outdir="results/annotation/prokka",
        prefix="sample"
    threads:
        config["threads"]
    shell:
        "prokka {input} --outdir {params.outdir} --prefix {params.prefix} --cpus {threads}"

rule summarize_results:
    input:
        quast="results/qc/quast/report.tsv",
        annotation="results/annotation/prokka/sample.gff"
    output:
        "results/summary/summary_table.tsv"
    shell:
        "python scripts/make_summary_table.py --quast {input.quast} --gff {input.annotation} --out {output}"
```

Please improve this template as needed.

## Conda environment files

Create simple conda environment YAML files.

If some tools are hard to install together, split environments by rule.

Use Bioconda where possible.

Example:

```yaml
name: epiferm-assembly
channels:
  - conda-forge
  - bioconda
  - defaults
dependencies:
  - flye
  - nanofilt
  - quast
  - prokka
  - snakemake
  - python
  - pandas
```

If a tool is heavy or difficult, document it instead of forcing installation.

## Important practical constraint

This is a one-day project.

Do not over-engineer.

If CheckM, GTDB-Tk, Bakta, or NanoMotif require large databases or difficult setup, do one of the following:

1. Add the Snakemake rule but keep it optional
2. Add clear documentation explaining how it would be run
3. Add mock/example output format
4. Explain why it was not run in the one-day sprint

Being honest about limitations is good. Do not pretend outputs were generated if they were not.

## README style

Write the README in a professional but accessible style.

Avoid hype.

Use language suitable for a job application portfolio.

Include this section:

```markdown
## Relevance to the EpiFerm Research Assistant position

This project was created to gain practical experience with long-read bacterial genome analysis workflows relevant to the EpiFerm project at UCPH FOOD. The workflow reconstructs a bacterial genome from Oxford Nanopore reads, evaluates assembly quality, annotates genomic features, and includes a methylation-aware extension. These steps mirror core tasks involved in linking bacterial genome structure and methylation profiles to strain-level phenotypes such as fermentation performance.
```

## Mini-report requirement

Create `report/mini_report.md`.

It should include:

1. Aim
2. Dataset
3. Workflow overview
4. Assembly results
5. QC interpretation
6. Annotation results
7. Taxonomy/completeness results if available
8. Methylation-aware extension
9. Relevance to EpiFerm
10. Limitations
11. Next steps

Keep it concise but meaningful.

## Add a CV/application section

Create `docs/application_notes.md`.

Include:

### CV bullet

```text
Built a Snakemake-based long-read bacterial genome analysis workflow using Oxford Nanopore data, including read filtering, Flye assembly, QUAST-based assembly QC, genome annotation, taxonomy assignment, and a methylation-aware NanoMotif extension.
```

### Cover letter sentence

```text
To strengthen my preparation for this role, I recently built a compact Snakemake-based long-read bacterial genome analysis workflow using Oxford Nanopore data, covering read filtering, bacterial genome assembly, assembly QC, annotation, taxonomy assignment, and a methylation-aware extension.
```

### Interview talking points

Include short answers to:

1. What is long-read sequencing useful for?
2. Why use Flye for bacterial genome assembly?
3. What does QUAST tell you?
4. What does CheckM tell you?
5. What is the role of methylation analysis in bacterial epigenetics?
6. What did you learn from building this project?
7. What would you improve with more time?

## Git and collaboration guidance

Because two people are working on the project, set up a simple collaboration workflow:

1. Main branch: stable version
2. Person A branch: `workflow`
3. Person B branch: `docs-report`
4. Use pull requests if possible
5. Write clear commit messages

Suggested commit messages:

```text
Initialize project structure
Add Snakemake workflow skeleton
Add NanoFilt and Flye rules
Add QUAST QC rule
Add annotation rule
Add tool principles documentation
Add mini-report draft
Add application notes
Polish README for job application
```

## Definition of done

The project is done when:

1. The repository has a clear README
2. The Snakemake workflow can be dry-run with `snakemake -n`
3. At least NanoFilt, Flye, QUAST, and Prokka/Bakta are implemented
4. CheckM, GTDB-Tk, and NanoMotif are either implemented or clearly documented as optional modules
5. The mini-report explains the results or expected outputs
6. The application notes clearly connect the project to the UCPH FOOD job
7. The project looks professional enough to share in an application or LinkedIn message

## Tone and teaching style

Be practical, direct, and beginner-friendly.

The user knows bioinformatics and programming but is new to this specific bacterial long-read assembly toolchain.

Explain concepts using examples.

When writing documentation, use a natural professional tone rather than AI-sounding language.

Do not claim expertise the user does not yet have. Phrase the project as hands-on preparation and demonstrated motivation.

## First task for Claude Code

Start by creating the repository structure and writing:

1. `README.md`
2. `config/config.yaml`
3. `Snakefile`
4. `docs/tool_principles.md`
5. `docs/application_notes.md`
6. `report/mini_report.md`
7. `.gitignore`

Then guide the user step by step through installing dependencies and selecting a small dataset.
