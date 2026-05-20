# Setup tutorial — getting the pipeline running on your laptop

A step-by-step guide to set up BacLR on a second machine and reproduce the
working environment. Written for macOS (Apple Silicon), since that is what the
project was first set up on; notes for Intel Mac and Linux are included.

Allow about 1-2 hours, most of it unattended while conda solves environments.

---

## 0. What you need first

- **Conda** (Miniforge, Miniconda, or Anaconda). Check with `conda --version`.
- **Git**, and access to the `BioDK/BacLR` repository.
- **~15 GB free disk** — the conda environments plus the raw data.
- On Apple Silicon Macs: **Rosetta 2**. Check with
  `/usr/bin/pgrep -q oahd && echo installed`. If it is not installed, run
  `softwareupdate --install-rosetta --agree-to-license`.

---

## 1. Get the code

```bash
git clone https://github.com/BioDK/BacLR.git
cd BacLR
```

If you cloned earlier, just update:

```bash
cd BacLR
git pull origin main
```

> **Branch note.** The project uses a single `main` branch. Always
> `git pull origin main` before you start working, and again before you
> `git push`. See section 8.

---

## 2. The one thing that makes macOS tricky: osx-64 emulation

Several tools in this pipeline (Flye, QUAST, CheckM2, Prokka, Bakta) have **no
native Apple-Silicon (arm64) builds** on Bioconda. They are only built for
Intel (`osx-64`). macOS can run Intel binaries through Rosetta 2, so the fix is
to create those conda environments as `osx-64` by prefixing the create command
with `CONDA_SUBDIR=osx-64`.

- **Apple Silicon Mac:** use `CONDA_SUBDIR=osx-64` exactly as shown below.
- **Intel Mac:** `osx-64` is already your native platform — the prefix is
  harmless, you can keep it or drop it.
- **Linux:** drop the `CONDA_SUBDIR=osx-64` prefix; Bioconda has native
  `linux-64` builds for everything.

Snakemake itself is pure Python and has a native arm64 build, so its
environment does **not** use the prefix.

---

## 3. Create the conda environments

The project uses **seven** small environments, one per workflow stage, instead
of one big environment. This is deliberate: the tools conflict if installed
together. Run these one at a time. Each prints a wall of solver output and ends
with "To activate this environment..." — that means it succeeded.

```bash
# Snakemake — native arm64, NO osx-64 prefix
conda create -n baclr-snakemake -c conda-forge -c bioconda 'snakemake-minimal>=7' -y

# Read filtering / QC
CONDA_SUBDIR=osx-64 conda create -n baclr-filtering \
  -c conda-forge -c bioconda 'python>=3.9' chopper nanoplot nanofilt -y

# Assembly
CONDA_SUBDIR=osx-64 conda create -n baclr-assembly \
  -c conda-forge -c bioconda 'python>=3.9' 'flye>=2.9' -y

# Assembly QC + completeness
CONDA_SUBDIR=osx-64 conda create -n baclr-qc \
  -c conda-forge -c bioconda 'python>=3.9' 'quast>=5.2' checkm2 pandas -y

# Annotation — Prokka. Note perl-xml-simple and perl-bioperl: Prokka needs
# them, and pinning them here makes the env's own Perl provide them.
CONDA_SUBDIR=osx-64 conda create -n baclr-annotation \
  -c conda-forge -c bioconda 'python>=3.9' prokka perl-xml-simple perl-bioperl -y

# Bakta — extended annotation module
CONDA_SUBDIR=osx-64 conda create -n baclr-bakta \
  -c conda-forge -c bioconda 'python>=3.9' bakta -y
```

The seventh environment, `baclr-nanomotif`, is for the methylation module.
That module is **disabled by default** (it needs raw-signal data the demo
dataset does not have — see [methylation_design.md](methylation_design.md)), so
you can skip it. If you do want it:

```bash
CONDA_SUBDIR=osx-64 conda create -n baclr-nanomotif \
  -c conda-forge -c bioconda 'python>=3.9' nanomotif -y
```

> The `baclr-nanomotif` solve can be slow under emulation. It is fine to skip —
> the core pipeline does not depend on it.

### Why the environments are split

Installing Prokka + Bakta + NanoMotif together makes conda's dependency solver
fail. The pipeline declares one conda environment per rule, so splitting them
into separate environments is transparent — it just works.

---

## 4. Verify the tools

Spot-check each environment. The Prokka check needs the PATH tweak (see the
note below):

```bash
conda run -n baclr-snakemake  snakemake --version
conda run -n baclr-filtering  chopper --version
conda run -n baclr-filtering  NanoPlot --version
conda run -n baclr-assembly   flye --version
conda run -n baclr-qc         quast.py --version
conda run -n baclr-qc         checkm2 --version
conda run -n baclr-bakta      bash -c 'export PATH="$CONDA_PREFIX/bin:$PATH" && bakta --version'
conda run -n baclr-annotation bash -c 'export PATH="$CONDA_PREFIX/bin:$PATH" && prokka --version'
```

Expected (versions may differ slightly):

| Tool | Version seen during setup |
|---|---|
| Snakemake | 9.5.1 |
| chopper | 0.11.0 |
| NanoPlot | 1.46.2 |
| Flye | 2.9.6 |
| QUAST | 5.3.0 |
| CheckM2 | 1.1.0 |
| Bakta | 1.12.0 |
| Prokka | 1.15.6 |

### The Prokka / Perl gotcha

Prokka is a Perl program. If you have another Perl earlier on your `PATH`
(very common on macOS — Homebrew installs one), Prokka picks up the wrong Perl
and fails with `Can't locate XML/Simple.pm`.

The fix is already built into the workflow: the `annotate_prokka` rule
prepends `$CONDA_PREFIX/bin` to `PATH`, which forces Prokka to use its own
environment's Perl. **You do not need to do anything** — just be aware that if
you test `prokka` by hand, prepend the PATH yourself (as in the check above),
or it may look broken when it is not.

---

## 5. Get the data

The raw reads are not in the repository (too large, and git-ignored). Download
them with the provided script, run from the repository root:

```bash
bash data/download_Bacillus_OxfordNanoporeMinION_ena_demo.sh
```

This fetches the first 100,000 Oxford Nanopore reads of *Bacillus subtilis*
run SRR10390699 (~672 MB) into `data/raw/`. Details are in
[../data/README.md](../data/README.md).

The download is a few hundred MB and can take several minutes depending on
your connection.

---

## 6. Dry-run the workflow

A dry-run builds the job graph and checks every input/output without running
anything. Always do this before a real run.

```bash
conda activate baclr-snakemake
snakemake -n
```

A successful dry-run ends with a job table listing 7 jobs (`all`,
`nanoplot_raw`, `filter_reads`, `assemble_flye`, `quast_qc`,
`annotate_prokka`, `summarize_results`) and the line
`This was a dry-run (flag -n).`

If you see an error instead, do not run for real — fix it first.

---

## 7. Run it for real

```bash
# still inside the baclr-snakemake environment
snakemake --use-conda --cores 8 --conda-frontend conda
```

- `--use-conda` tells Snakemake to run each rule inside the conda environment
  declared for it (the `envs/*.yaml` files).
- `--cores 8` — adjust to the number of CPU cores you want to use.
- `--conda-frontend conda` — use the plain conda solver. (Snakemake may try
  `mamba` by default; this avoids needing it.)

The first run is slower because Snakemake builds the per-rule environments from
the `envs/*.yaml` files. Outputs land under `results/{sample}/...`.

> **Heads up:** Snakemake's `--use-conda` builds its own environments from the
> `envs/*.yaml` files. These will be created as your default platform. On
> Apple Silicon that means it may try arm64 builds and fail for the same
> reason described in section 2. If that happens, set the subdir for the run:
>
> ```bash
> CONDA_SUBDIR=osx-64 snakemake --use-conda --cores 8 --conda-frontend conda
> ```
>
> Coordinate with the team if you hit this — there is a project note about
> using the pre-built environments directly.

---

## 8. Working with Git (single-branch workflow)

The project uses one branch, `main`. The routine:

```bash
git pull origin main          # 1. ALWAYS pull first
# ... do your work, edit files ...
git add <files>               # 2. stage what you changed
git commit -m "Clear message" # 3. commit
git pull origin main          # 4. pull again (in case of new changes)
git push origin main          # 5. push
```

Rules of thumb:

- **Pull before you start, pull again before you push.** Most conflicts come
  from working on a stale copy.
- **Never commit large data.** `data/raw/`, FASTQ files, BAMs, and reference
  databases are git-ignored on purpose. If `git status` ever shows a `.fastq`
  or a database, stop and check `.gitignore`.
- **Write clear commit messages** — one line saying what changed and why.

---

## Quick troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `conda create` fails with "nothing provides ..." | arm64 build missing | Add the `CONDA_SUBDIR=osx-64` prefix (section 2) |
| Prokka: `Can't locate XML/Simple.pm` | wrong Perl on PATH | Prepend `$CONDA_PREFIX/bin` to PATH (section 4) |
| Combined Prokka+Bakta env will not solve | known conflict | Use the separate environments (section 3) |
| `snakemake -n` WildcardError | inconsistent paths | Should not happen on current `main`; `git pull` |
| `--use-conda` env build fails on arm64 | same as section 2 | Prefix the run with `CONDA_SUBDIR=osx-64` |
| Conda solve takes very long | `osx-64` emulation + large index | Normal; let it run, do not interrupt |

---

## Where to read more

- [workflow_overview.md](workflow_overview.md) — what the pipeline does
- [tool_principles.md](tool_principles.md) — what each tool does and why
- [methylation_design.md](methylation_design.md) — the methylation module
- [../data/README.md](../data/README.md) — the dataset
