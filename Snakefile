# =============================================================================
# Long-read bacterial genome reconstruction & methylation-aware annotation
# =============================================================================
# This is a Snakemake workflow. Snakemake builds a dependency graph from the
# input/output declarations of each rule and runs only what is needed, in the
# right order, in parallel where possible. You ask for a final file and it
# figures out the chain of steps required to produce it.
#
# Run a dry-run (prints the plan, executes nothing):
#     snakemake -n
#
# Run for real, with one conda environment created per rule:
#     snakemake --use-conda --cores 8
#
# Visualise the dependency graph:
#     snakemake --dag | dot -Tsvg > dag.svg
# -----------------------------------------------------------------------------

# Load all tunable parameters from the config file. After this line, settings
# are available as config["key"].
configfile: "config/config.yaml"

SAMPLE = config["sample"]

# -----------------------------------------------------------------------------
# Build the list of final target files.
#
# `rule all` is a convention: it has no shell command, only inputs. Those
# inputs are what we ask Snakemake to produce. We build the list dynamically
# so that optional modules are only requested when enabled in config.yaml.
# -----------------------------------------------------------------------------
TARGETS = [
    f"results/filtered_reads/{SAMPLE}.filtered.fastq.gz",
    f"results/qc/{SAMPLE}/nanoplot_raw/NanoStats.txt",
    f"results/assembly/{SAMPLE}/flye/assembly.fasta",
    f"results/qc/{SAMPLE}/quast/report.tsv",
    f"results/annotation/{SAMPLE}/prokka/{SAMPLE}.gff",
    f"results/summary/{SAMPLE}/summary_table.tsv",
]

# Extended modules - real rules, only run when switched on in config.
if config["run_checkm"]:
    TARGETS.append(f"results/qc/{SAMPLE}/checkm2/quality_report.tsv")
if config["run_bakta"]:
    TARGETS.append(f"results/annotation/{SAMPLE}/bakta/{SAMPLE}.gff3")

# Documented-only modules - rules exist so the workflow is complete, but they
# need large databases / special input data (see docs/). Keep these false in
# config.yaml unless you have set up the prerequisites.
if config["run_gtdbtk"]:
    TARGETS.append(f"results/taxonomy/{SAMPLE}/gtdbtk/gtdbtk.bac120.summary.tsv")
if config["run_nanomotif"]:
    TARGETS.append(f"results/methylation/{SAMPLE}/nanomotif/motifs.tsv")


rule all:
    input:
        TARGETS


# =============================================================================
# CORE RULES  (run on a laptop in the one-day sprint)
# =============================================================================

# -----------------------------------------------------------------------------
# Read QC on the RAW reads, before any filtering.
# NanoPlot summarises read-length and quality distributions. Looking at this
# first tells you how aggressively you can afford to filter.
# -----------------------------------------------------------------------------
rule nanoplot_raw:
    input:
        config["raw_reads"]
    output:
        stats="results/qc/{sample}/nanoplot_raw/NanoStats.txt"
    params:
        outdir="results/qc/{sample}/nanoplot_raw"
    threads:
        config["threads"]
    conda:
        "envs/filtering.yaml"
    shell:
        "NanoPlot --fastq {input} --outdir {params.outdir} "
        "--threads {threads} --tsv_stats"


# -----------------------------------------------------------------------------
# Read filtering with chopper (the maintained successor to NanoFilt; same
# author, same idea, faster). Drops reads below a quality and length cutoff.
# chopper reads FASTQ from stdin and writes to stdout, so we stream through it.
# -----------------------------------------------------------------------------
rule filter_reads:
    input:
        config["raw_reads"]
    output:
        "results/filtered_reads/{sample}.filtered.fastq.gz"
    params:
        q=config["quality_cutoff"],
        l=config["min_length"]
    threads:
        config["threads"]
    conda:
        "envs/filtering.yaml"
    shell:
        "gunzip -c {input} | chopper -q {params.q} -l {params.l} "
        "--threads {threads} | gzip > {output}"


# -----------------------------------------------------------------------------
# De novo genome assembly with Flye.
# Flye reconstructs the genome from overlapping long reads. Bacterial
# chromosomes are usually a single circular molecule, so a good assembly often
# yields one (or few) long contigs.
#
# NOTE on outputs: Flye writes a whole directory. We declare assembly.fasta as
# the marker output and direct Flye at a fresh out-dir each run. The shell
# command removes a stale out-dir first so re-runs do not error.
# -----------------------------------------------------------------------------
rule assemble_flye:
    input:
        "results/filtered_reads/{sample}.filtered.fastq.gz"
    output:
        fasta="results/assembly/{sample}/flye/assembly.fasta",
        info="results/assembly/{sample}/flye/assembly_info.txt"
    params:
        outdir="results/assembly/{sample}/flye",
        genome_size=config["genome_size"],
        mode=config["flye_mode"]
    threads:
        config["threads"]
    conda:
        "envs/assembly.yaml"
    shell:
        "rm -rf {params.outdir} && "
        "flye {params.mode} {input} --out-dir {params.outdir} "
        "--genome-size {params.genome_size} --threads {threads}"


# -----------------------------------------------------------------------------
# Assembly QC with QUAST.
# Reports contig count, total length, N50, GC% - the basic numbers that tell
# you whether the assembly is contiguous and the right size.
# -----------------------------------------------------------------------------
rule quast_qc:
    input:
        "results/assembly/{sample}/flye/assembly.fasta"
    output:
        "results/qc/{sample}/quast/report.tsv"
    params:
        outdir="results/qc/{sample}/quast"
    threads:
        config["threads"]
    conda:
        "envs/qc.yaml"
    shell:
        "quast.py {input} -o {params.outdir} --threads {threads}"


# -----------------------------------------------------------------------------
# Genome annotation with Prokka (default annotator).
# Predicts genes (CDS), rRNA, tRNA and assigns putative functions.
# Prokka requires its output directory to not already exist, hence the rm -rf.
#
# PATH note: Prokka is a Perl program and its scripts use a "#!/usr/bin/env
# perl" shebang. On a machine with another Perl earlier on PATH (e.g. a
# Homebrew Perl on macOS), that wrong Perl gets used and Prokka fails to find
# its modules. Putting $CONDA_PREFIX/bin at the front of PATH forces Prokka to
# use the Perl from its own conda environment. This is portable - it works on
# any machine because $CONDA_PREFIX is set by conda when the env is activated.
# -----------------------------------------------------------------------------
rule annotate_prokka:
    input:
        "results/assembly/{sample}/flye/assembly.fasta"
    output:
        gff="results/annotation/{sample}/prokka/{sample}.gff",
        txt="results/annotation/{sample}/prokka/{sample}.txt"
    params:
        outdir="results/annotation/{sample}/prokka",
        prefix="{sample}"
    threads:
        config["threads"]
    conda:
        "envs/annotation.yaml"
    shell:
        "export PATH=\"$CONDA_PREFIX/bin:$PATH\" && "
        "rm -rf {params.outdir} && "
        "prokka {input} --outdir {params.outdir} --prefix {params.prefix} "
        "--cpus {threads} --force"


# -----------------------------------------------------------------------------
# Merge the key QC and annotation numbers into a single summary table.
# This is the one file a reader would look at to judge the run at a glance.
# -----------------------------------------------------------------------------
rule summarize_results:
    input:
        quast="results/qc/{sample}/quast/report.tsv",
        gff="results/annotation/{sample}/prokka/{sample}.gff"
    output:
        "results/summary/{sample}/summary_table.tsv"
    conda:
        "envs/qc.yaml"
    shell:
        "python scripts/make_summary_table.py "
        "--quast {input.quast} --gff {input.gff} --out {output}"


# =============================================================================
# EXTENDED RULES  (run if the conda environments install cleanly)
# =============================================================================

# -----------------------------------------------------------------------------
# Genome completeness & contamination with CheckM2.
# CheckM2 uses a machine-learning model over gene content to estimate how
# complete the genome is and how much foreign sequence may be mixed in.
# Requires a ~3 GB database (see docs/tool_principles.md to download it).
# -----------------------------------------------------------------------------
rule checkm2_qc:
    input:
        "results/assembly/{sample}/flye/assembly.fasta"
    output:
        "results/qc/{sample}/checkm2/quality_report.tsv"
    params:
        outdir="results/qc/{sample}/checkm2",
        db=config["checkm2_db"]
    threads:
        config["threads"]
    conda:
        "envs/checkm2.yaml"
    shell:
        "checkm2 predict --input {input} --output-directory {params.outdir} "
        "--threads {threads} --database_path {params.db} --force"


# -----------------------------------------------------------------------------
# Functional annotation with Bakta (light database).
# Bakta gives richer, more standardised functional annotation than Prokka.
# The light DB (~3 GB unpacked) is enough for this project.
# -----------------------------------------------------------------------------
rule bakta_annotate:
    input:
        "results/assembly/{sample}/flye/assembly.fasta"
    output:
        gff="results/annotation/{sample}/bakta/{sample}.gff3"
    params:
        outdir="results/annotation/{sample}/bakta",
        prefix="{sample}",
        db=config["bakta_db"]
    threads:
        config["threads"]
    conda:
        "envs/bakta.yaml"
    shell:
        "bakta {input} --output {params.outdir} --prefix {params.prefix} "
        "--db {params.db} --threads {threads} --force"


# =============================================================================
# DOCUMENTED-ONLY RULES  (keep disabled unless prerequisites are set up)
# =============================================================================

# -----------------------------------------------------------------------------
# Taxonomic classification with GTDB-Tk.
# Places the genome in the standardised GTDB taxonomy and confirms the
# organism's identity. The reference database is ~110 GB, so this is NOT run
# in the one-day sprint - the rule is here for completeness.
# See docs/tool_principles.md for the concept and how it would be run.
# -----------------------------------------------------------------------------
rule gtdbtk_classify:
    input:
        "results/assembly/{sample}/flye/assembly.fasta"
    output:
        "results/taxonomy/{sample}/gtdbtk/gtdbtk.bac120.summary.tsv"
    params:
        indir="results/assembly/{sample}/flye",
        outdir="results/taxonomy/{sample}/gtdbtk",
        db=config["gtdbtk_db"]
    threads:
        config["threads"]
    conda:
        "envs/taxonomy.yaml"
    shell:
        "GTDBTK_DATA_PATH={params.db} gtdbtk classify_wf "
        "--genome_dir {params.indir} --out_dir {params.outdir} "
        "--extension fasta --cpus {threads} --skip_ani_screen"


# -----------------------------------------------------------------------------
# Methylation motif discovery with NanoMotif.
# IMPORTANT: NanoMotif does NOT work on plain FASTQ. It needs modification-aware
# basecalled data (a modBAM with MM/ML tags) plus the assembly. This rule is a
# placeholder showing the intended command. See docs/methylation_design.md for
# the full data requirements and a worked example of the output format.
# -----------------------------------------------------------------------------
rule nanomotif_methylation:
    input:
        assembly="results/assembly/{sample}/flye/assembly.fasta",
        pileup="results/methylation/{sample}/modkit_pileup.bed"
    output:
        "results/methylation/{sample}/nanomotif/motifs.tsv"
    params:
        outdir="results/methylation/{sample}/nanomotif"
    threads:
        config["threads"]
    conda:
        "envs/nanomotif.yaml"
    shell:
        "nanomotif motif_discovery {input.assembly} {input.pileup} "
        "--out {params.outdir} --threads {threads}"
