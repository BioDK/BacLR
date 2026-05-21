# Running and testing the pipeline

How to run BacLR, check that it worked, test individual pieces, and recover
when something goes wrong.

This guide assumes the project is already set up — conda environments created
and the dataset downloaded. If not, do [`setup_tutorial.md`](setup_tutorial.md)
first.

---

## 1. The two-command workflow

Every run is the same two steps. **Always dry-run first.**

```bash
conda activate baclr-snakemake

# 1. Dry-run — builds the job graph, checks inputs/outputs, runs nothing
snakemake -n

# 2. Real run
#    Track I (Intel Mac):
snakemake --use-conda --cores 8 --conda-frontend conda
#    Track A (Apple Silicon):
CONDA_SUBDIR=osx-64 snakemake --use-conda --cores 8 --conda-frontend conda
```

(Not sure which track you are? Run `uname -m` — `x86_64` is Intel/Track I,
`arm64` is Apple Silicon/Track A. See [`setup_tutorial.md`](setup_tutorial.md).)

**What the flags mean:**

| Flag | Meaning |
|------|---------|
| `-n` | Dry-run: print the plan, execute nothing |
| `--use-conda` | Run each rule in its declared conda environment |
| `--cores 8` | Use up to 8 CPU cores (adjust to your machine) |
| `--conda-frontend conda` | Use the plain conda solver (not mamba) |
| `-p` / `--printshellcmds` | Also print each shell command as it runs (useful for debugging) |

**Before the very first run**, make sure conda is recent enough — Snakemake's
`--use-conda` needs conda ≥ 24.7.1:

```bash
conda --version
# if older than 24.7.1:
conda install -n baclr-snakemake -c conda-forge 'conda>=24.7.1' -y
```

---

## 2. What a successful dry-run looks like

`snakemake -n` should end with a job table and the dry-run line:

```
Job stats:
job                  count
-----------------  -------
all                      1
annotate_prokka          1
assemble_flye            1
filter_reads             1
nanoplot_raw             1
quast_qc                 1
summarize_results        1
total                    7

This was a dry-run (flag -n). The order of jobs does not reflect the order of execution.
```

Seven jobs for the core pipeline. If you see an **error** instead (for example
a `WildcardError`), do not run for real — fix it first (see section 7).

---

## 3. What a successful real run looks like

The first real run is slow: Snakemake builds a conda environment for each rule
before running anything. After that it runs the seven jobs. The longest single
step is the Flye assembly (tens of minutes for a few-Mb genome).

A successful run ends with:

```
7 of 7 steps (100%) done
Complete log(s): .snakemake/log/<timestamp>.snakemake.log
```

The run stops at the first failing rule and prints an `Error in rule ...`
block. Completed steps are kept, so a re-run resumes from where it stopped (see
section 6).

---

## 4. Checking the results

After a successful run, the key outputs are under `results/`. Replace
`bsubtilis_MB9_B6` with your `sample` value if different.

**The one-glance summary:**

```bash
cat results/summary/bsubtilis_MB9_B6/summary_table.tsv
```

This merges the headline QC and annotation numbers into a single table.

**The assembly — is it one circular chromosome?**

```bash
cat results/assembly/bsubtilis_MB9_B6/flye/assembly_info.txt
```

Each row is a contig: length, coverage, and `circ.` (Y/N). For a single-
chromosome bacterium you want one long contig near the expected genome size,
marked `Y`.

**Assembly QC numbers:**

```bash
cat results/qc/bsubtilis_MB9_B6/quast/report.txt
```

**What to sanity-check:**

| Output | Looks healthy if... |
|--------|---------------------|
| Filtered reads | a modest fraction removed; enough bases for good coverage |
| `assembly_info.txt` | one long circular contig near the expected genome size |
| QUAST `report` | low contig count, large N50, GC% matching the organism |
| Prokka counts | a few thousand CDS, dozens of tRNA, a handful of rRNA operons |

How to interpret each number in depth is in
[`tool_principles.md`](tool_principles.md).

---

## 5. Testing individual pieces

### Test one rule without running the whole pipeline

Ask Snakemake for a single output file — it runs only what is needed to
produce it:

```bash
# just the filtering step
snakemake --use-conda --cores 4 --conda-frontend conda \
  results/filtered_reads/bsubtilis_MB9_B6.filtered.fastq.gz

# just up to the assembly
snakemake --use-conda --cores 8 --conda-frontend conda \
  results/assembly/bsubtilis_MB9_B6/flye/assembly.fasta
```

(Track A: prefix with `CONDA_SUBDIR=osx-64` as in section 1.)

### Test that a tool works on its own

Each environment can be spot-checked directly:

```bash
conda run -n baclr-filtering chopper --version
conda run -n baclr-assembly   flye --version
conda run -n baclr-qc         quast.py --version
# Prokka needs its env's Perl first on PATH:
conda run -n baclr-annotation bash -c 'export PATH="$CONDA_PREFIX/bin:$PATH" && prokka --version'
```

### Test the summary script

The Python helper has no bioinformatics dependencies and can be tested with
small hand-made inputs:

```bash
# make a tiny fake QUAST report and GFF, then run the script
printf '# contigs\t1\nTotal length\t4000000\nN50\t4000000\nGC (%%)\t43.5\n' > /tmp/q.tsv
printf '##gff-version 3\nc1\tx\tCDS\t1\t90\t.\t+\t0\tID=g1\n' > /tmp/a.gff
python scripts/make_summary_table.py --quast /tmp/q.tsv --gff /tmp/a.gff --out /tmp/s.tsv
cat /tmp/s.tsv
```

### Visualise the workflow graph

```bash
snakemake --dag | dot -Tsvg > dag.svg
```

Opens as a diagram of which rule feeds which — handy for understanding the
pipeline or checking a change.

---

## 6. Re-running and cleaning up

**Resume after a failure.** Just run the same command again. Snakemake keeps
completed outputs and restarts from the failed step.

**Force a rule to re-run** even though its output exists:

```bash
snakemake --use-conda --cores 8 --conda-frontend conda -f quast_qc
```

**Re-run everything from scratch** — delete the results and run again:

```bash
rm -rf results/assembly results/qc results/annotation \
       results/summary results/filtered_reads
# (keeps results/methylation/example_output, which is committed)
snakemake --use-conda --cores 8 --conda-frontend conda
```

**Rebuild a conda environment.** If you change an `envs/*.yaml` file,
Snakemake rebuilds that environment automatically on the next run. To force it,
delete the cached environment:

```bash
rm -rf .snakemake/conda
```

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `CreateCondaEnvironmentException: Conda must be version 24.7.1 or later` | System conda too old | `conda install -n baclr-snakemake -c conda-forge 'conda>=24.7.1' -y` |
| `conda create` / env build fails: "nothing provides ..." | On Apple Silicon, env built as `arm64` | Prefix the command with `CONDA_SUBDIR=osx-64` |
| QUAST: `No module named 'distutils'` | QUAST needs Python <3.12 | Already pinned in `envs/qc.yaml`; `git pull` and let the qc env rebuild |
| Prokka: `Can't locate XML/Simple.pm` | A non-env Perl is first on PATH | Built into the rule (`$CONDA_PREFIX/bin` on PATH); when testing by hand, prepend it yourself |
| `snakemake -n` `WildcardError` | Inconsistent rule paths | Should not happen on current `main`; `git pull origin main` |
| `Directory cannot be locked` | A previous run was interrupted | `snakemake --unlock`, then re-run |
| A rule fails mid-run | Tool-specific error | Read the `Error in rule` block, then the full log under `.snakemake/log/` |

When a rule fails, the most useful detail is in the per-run log printed at the
end of the output:

```bash
ls -t .snakemake/log/ | head -1     # most recent log file
```

---

## 8. Running the optional modules

The extended modules (CheckM2, Bakta) and the documented-only modules
(GTDB-Tk, NanoMotif) are off by default. To enable one:

1. Install its database (CheckM2 and Bakta light DB are ~3 GB each; see
   [`tool_principles.md`](tool_principles.md) for the download commands).
2. Set its path and flag in `config/config.yaml`, e.g. `run_checkm: true` and
   `checkm2_db: "db/checkm2"`.
3. Dry-run (`snakemake -n`) — the new job should appear in the plan.
4. Run as normal.

Each optional module has its own conda environment (`envs/checkm2.yaml`,
`envs/bakta.yaml`, etc.), built automatically by `--use-conda` on first use.

---

## Quick reference

```bash
conda activate baclr-snakemake

snakemake -n                                         # dry-run (always first)
snakemake --use-conda --cores 8 --conda-frontend conda   # run (Intel)
CONDA_SUBDIR=osx-64 snakemake --use-conda --cores 8 --conda-frontend conda  # run (Apple Silicon)

snakemake --use-conda --cores 8 --conda-frontend conda <target>  # build one file
snakemake -f <rule>                                  # force-rerun a rule
snakemake --unlock                                   # clear a stale lock
snakemake --dag | dot -Tsvg > dag.svg                # workflow diagram
```
