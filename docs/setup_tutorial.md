# Setup tutorial — getting the pipeline running on your laptop

A step-by-step guide to set up BacLR on a machine and reproduce the working
environment. The goal is for everyone on the team to have an identical,
working setup — same tools, same versions, same result.

The project is developed on **two kinds of Mac**, and the setup differs in
exactly one respect (how conda environments are created). This guide is
**dual-track**: wherever the steps differ, both are shown side by side. Find
your machine first, then follow your track throughout.

Allow about 1-2 hours, most of it unattended while conda solves environments.

---

## 0. First: which machine do you have?

Run this to find out:

```bash
uname -m
```

| `uname -m` prints | Your machine | Your track |
|---|---|---|
| `x86_64` | **Intel Mac** | Track **I** |
| `arm64` | **Apple Silicon** (M1/M2/M3/M4) | Track **A** |

You can also check: Apple menu > About This Mac. "Intel" = Track I, "Apple
M..." = Track A.

**The one difference between the tracks:** the bioinformatics tools used here
(Flye, QUAST, CheckM2, Prokka, Bakta) are distributed by Bioconda as Intel
(`osx-64`) builds.

- **Track I (Intel):** `osx-64` is your native platform. You install
  everything normally — nothing special.
- **Track A (Apple Silicon):** your native platform is `arm64`, which has no
  builds for these tools. You create the conda environments as `osx-64` and
  macOS runs them through Rosetta 2 translation. In practice this just means
  prefixing each `conda create` with `CONDA_SUBDIR=osx-64`.

Everything else — git, the data, the dry-run, the actual run — is identical
for both.

> **Why both tracks land in the same place:** whether the binaries are native
> (Intel) or translated (Apple Silicon), they are the *same* Bioconda `osx-64`
> packages at the *same* versions. The pipeline produces the same output. The
> only practical difference for Track A is that conda solves run a little
> slower under emulation.

---

## 1. What you need first

- **Conda** (Miniforge, Miniconda, or Anaconda). Check with `conda --version`.
- **Git**, and access to the `BioDK/BacLR` repository.
- **~15 GB free disk** — the conda environments plus the raw data.
- **Track A only — Rosetta 2.** Check with
  `/usr/bin/pgrep -q oahd && echo installed`. If nothing prints, install it:
  `softwareupdate --install-rosetta --agree-to-license`.
  (Track I: skip this — Rosetta is not needed.)

---

## 2. Get the code

Same for both tracks:

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

## 3. Create the conda environments

The project uses **seven** small environments, one per workflow stage, instead
of one big environment. This is deliberate: the tools conflict if installed
together (installing Prokka + Bakta + NanoMotif as one environment makes
conda's solver fail). The pipeline declares one conda environment per rule, so
the split is transparent — it just works.

Run the commands **one at a time**. Each prints a wall of solver output and
ends with "To activate this environment..." — that means it succeeded.

**Pick your track.** The commands are identical except that Track A prefixes
the bio-tool environments with `CONDA_SUBDIR=osx-64`. The Snakemake
environment is pure Python and never needs the prefix on either track.

**Stuck at solving enviroment.** If you get stuck at solving enviroment, then try to use "mamba create" instead of "conda create", becuase Mamba solves dependencies much faster.  Run the command line below to install mamba: 
```conda install -n base -c conda-forge mamba -y```

### Track I — Intel Mac

```bash
conda create -n baclr-snakemake -c conda-forge -c bioconda 'snakemake-minimal>=7' -y

conda create -n baclr-filtering \
  -c conda-forge -c bioconda 'python>=3.9' chopper nanoplot nanofilt -y

conda create -n baclr-assembly \
  -c conda-forge -c bioconda 'python>=3.9' 'flye>=2.9' -y

conda create -n baclr-qc \
  -c conda-forge -c bioconda 'python>=3.9' 'quast>=5.2' checkm2 pandas -y

# Prokka. perl-xml-simple and perl-bioperl are pinned so the env's own
# Perl provides them (Prokka needs them).
conda create -n baclr-annotation \
  -c conda-forge -c bioconda 'python>=3.9' prokka perl-xml-simple perl-bioperl -y

conda create -n baclr-bakta \
  -c conda-forge -c bioconda 'python>=3.9' bakta -y
```

### Track A — Apple Silicon

Identical, but every bio-tool environment is prefixed with
`CONDA_SUBDIR=osx-64` (Snakemake is not):

```bash
conda create -n baclr-snakemake -c conda-forge -c bioconda 'snakemake-minimal>=7' -y

CONDA_SUBDIR=osx-64 conda create -n baclr-filtering \
  -c conda-forge -c bioconda 'python>=3.9' chopper nanoplot nanofilt -y

CONDA_SUBDIR=osx-64 conda create -n baclr-assembly \
  -c conda-forge -c bioconda 'python>=3.9' 'flye>=2.9' -y

CONDA_SUBDIR=osx-64 conda create -n baclr-qc \
  -c conda-forge -c bioconda 'python>=3.9' 'quast>=5.2' checkm2 pandas -y

CONDA_SUBDIR=osx-64 conda create -n baclr-annotation \
  -c conda-forge -c bioconda 'python>=3.9' prokka perl-xml-simple perl-bioperl -y

CONDA_SUBDIR=osx-64 conda create -n baclr-bakta \
  -c conda-forge -c bioconda 'python>=3.9' bakta -y
```

> **Track A note:** these solves run slower than on Intel because conda is
> resolving `osx-64` packages on an `arm64` host. A solve taking several
> minutes is normal — let it finish, do not interrupt it.

### The optional seventh environment (both tracks)

`baclr-nanomotif` is for the methylation module. That module is **disabled by
default** — it needs raw-signal data the demo dataset does not have (see
[methylation_design.md](methylation_design.md)) — so you can **skip this
environment**. The core pipeline does not depend on it.

If you do want it: Track I drops the prefix, Track A keeps it.

```bash
# Track I
conda create -n baclr-nanomotif -c conda-forge -c bioconda 'python>=3.9' nanomotif -y
# Track A
CONDA_SUBDIR=osx-64 conda create -n baclr-nanomotif -c conda-forge -c bioconda 'python>=3.9' nanomotif -y
```

---

## 4. Verify the tools

Same for both tracks. Spot-check each environment. The Prokka check needs the
PATH tweak (see the note below):

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

### The Prokka / Perl gotcha (both tracks)

Prokka is a Perl program. If you have another Perl earlier on your `PATH`,
Prokka picks up the wrong Perl and fails with `Can't locate XML/Simple.pm`.
This happens on **both Intel and Apple Silicon** Macs — the usual culprit is a
Homebrew-installed Perl, which is common on either machine.

The fix is already built into the workflow: the `annotate_prokka` rule
prepends `$CONDA_PREFIX/bin` to `PATH`, which forces Prokka to use its own
environment's Perl. **You do not need to do anything in the pipeline** — just
be aware that if you test `prokka` by hand, prepend the PATH yourself (as in
the check above), or it may look broken when it is not.

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

**Before the first run — check your conda version.** Snakemake's `--use-conda`
requires conda **24.7.1 or newer**. Check with `conda --version`. If it is
older, install a modern conda *into the snakemake environment* (this leaves
your system conda untouched):

```bash
conda install -n baclr-snakemake -c conda-forge 'conda>=24.7.1' -y
```

Then run the pipeline:

```bash
# still inside the baclr-snakemake environment

# Track I — Intel Mac
snakemake --use-conda --cores 8 --conda-frontend conda

# Track A — Apple Silicon (note the CONDA_SUBDIR prefix)
CONDA_SUBDIR=osx-64 snakemake --use-conda --cores 8 --conda-frontend conda
```

- `--use-conda` tells Snakemake to run each rule inside the conda environment
  declared for it (the `envs/*.yaml` files).
- `--cores 8` — adjust to the number of CPU cores you want to use.
- `--conda-frontend conda` — use the plain conda solver. (Snakemake may try
  `mamba` by default; this avoids needing it.)

The first run is slower because Snakemake builds the per-rule environments from
the `envs/*.yaml` files. Outputs land under `results/{sample}/...`.

> **Why Track A needs the prefix here too:** `--use-conda` makes Snakemake
> build its *own* copies of the environments from the `envs/*.yaml` files —
> separate from the ones you created in section 3. On Apple Silicon those
> builds would default to `arm64` and fail, exactly as a plain `conda create`
> would. The `CONDA_SUBDIR=osx-64` prefix forces them to `osx-64`.
> Track I needs nothing extra — `osx-64` is already native.

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

| Symptom | Track | Likely cause | Fix |
|---|---|---|---|
| `conda create` fails: "nothing provides ..." | A | env created as `arm64`, no builds exist | Add the `CONDA_SUBDIR=osx-64` prefix (section 3) |
| `--use-conda` env build fails | A | Snakemake built its envs as `arm64` | Prefix the run with `CONDA_SUBDIR=osx-64` (section 7) |
| Conda solve takes very long | A | `osx-64` emulation + large package index | Normal under emulation; let it run, do not interrupt |
| `CreateCondaEnvironmentException: Conda must be version 24.7.1 or later` | I + A | system conda too old for Snakemake's `--use-conda` | Install a modern conda *into* the snakemake env (does not touch your base conda): `conda install -n baclr-snakemake -c conda-forge 'conda>=24.7.1' -y` |
| QUAST fails: `No module named 'distutils'` | I + A | QUAST needs `distutils`, removed in Python 3.12 | Already fixed: `envs/qc.yaml` pins `python<3.12`. If hit, `git pull origin main` and let Snakemake rebuild the qc env |
| Prokka: `Can't locate XML/Simple.pm` | I + A | wrong Perl earlier on PATH (often Homebrew) | Prepend `$CONDA_PREFIX/bin` to PATH (section 4) |
| Combined Prokka+Bakta env will not solve | I + A | known dependency conflict | Use the separate environments (section 3) |
| `snakemake -n` WildcardError | I + A | inconsistent rule paths | Should not happen on current `main`; `git pull origin main` |

Track key: **I** = Intel Mac, **A** = Apple Silicon. Rows marked **I + A**
affect both.

---

## Where to read more

- [workflow_overview.md](workflow_overview.md) — what the pipeline does
- [tool_principles.md](tool_principles.md) — what each tool does and why
- [methylation_design.md](methylation_design.md) — the methylation module
- [../data/README.md](../data/README.md) — the dataset
