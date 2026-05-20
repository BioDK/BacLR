#!/usr/bin/env python3
"""Build a one-file summary table from QUAST QC and a Prokka GFF annotation.

This is the final step of the core workflow. It collapses the most important
numbers from two separate outputs into a single tab-separated table that a
reader can scan in a few seconds to judge the run.

Usage (called by the Snakemake rule `summarize_results`):

    python scripts/make_summary_table.py \\
        --quast results/qc/quast/report.tsv \\
        --gff   results/annotation/prokka/sample.gff \\
        --out   results/summary/summary_table.tsv

The script depends only on the Python standard library, so it runs in any of
the project's conda environments.
"""

import argparse
import os
import sys

# Reuse the QUAST parser from the sibling script.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from summarize_quast import parse_quast  # noqa: E402


def count_features(gff_path):
    """Count annotated feature types in a Prokka/Bakta GFF file.

    A GFF file has one feature per line; column 3 is the feature type
    (CDS, tRNA, rRNA, tmRNA, ...). Lines starting with '#' are headers, and
    Prokka appends the FASTA sequence after a '##FASTA' line - we stop there.
    """
    counts = {}
    with open(gff_path) as fh:
        for line in fh:
            if line.startswith("##FASTA"):
                break
            if line.startswith("#") or not line.strip():
                continue
            fields = line.split("\t")
            if len(fields) < 3:
                continue
            feature_type = fields[2]
            counts[feature_type] = counts.get(feature_type, 0) + 1
    return counts


def main():
    ap = argparse.ArgumentParser(
        description="Merge QUAST QC and GFF annotation into a summary table."
    )
    ap.add_argument("--quast", required=True, help="QUAST report.tsv")
    ap.add_argument("--gff", required=True, help="Prokka/Bakta GFF file")
    ap.add_argument("--out", required=True, help="output summary TSV path")
    args = ap.parse_args()

    # --- Collect metrics ------------------------------------------------------
    try:
        quast_metrics = parse_quast(args.quast)
    except FileNotFoundError:
        sys.exit(f"ERROR: QUAST report not found: {args.quast}")

    try:
        feature_counts = count_features(args.gff)
    except FileNotFoundError:
        sys.exit(f"ERROR: GFF annotation not found: {args.gff}")

    # --- Assemble the summary -------------------------------------------------
    summary = []
    summary.append(("--- Assembly QC (QUAST) ---", ""))
    for label, value in quast_metrics.items():
        summary.append((label, value))

    summary.append(("--- Annotation (GFF) ---", ""))
    # Show the biologically interesting feature types first, then anything else.
    for ft in ("CDS", "tRNA", "rRNA", "tmRNA"):
        if ft in feature_counts:
            summary.append((f"{ft}_count", feature_counts[ft]))
    for ft, n in sorted(feature_counts.items()):
        if ft not in ("CDS", "tRNA", "rRNA", "tmRNA"):
            summary.append((f"{ft}_count", n))

    # --- Write it out ---------------------------------------------------------
    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(args.out, "w") as fh:
        fh.write("metric\tvalue\n")
        for label, value in summary:
            fh.write(f"{label}\t{value}\n")

    print(f"Summary table written to {args.out}")
    for label, value in summary:
        print(f"  {label}\t{value}")


if __name__ == "__main__":
    main()
