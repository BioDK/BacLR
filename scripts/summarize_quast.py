#!/usr/bin/env python3
"""Parse a QUAST report.tsv into a clean, ordered dictionary of key metrics.

QUAST writes its main report as a two-column TSV: metric name in column 1,
value in column 2. This helper pulls out the handful of fields that matter for
a bacterial assembly and returns them in a predictable order.

It is used by make_summary_table.py but can also be run standalone:

    python scripts/summarize_quast.py --quast results/qc/quast/report.tsv
"""

import argparse
import csv
import sys

# QUAST metric names we care about, mapped to the label we want to display.
# QUAST's exact wording can vary slightly between versions, so we match on a
# substring rather than the full string.
WANTED = [
    ("# contigs", "num_contigs"),
    ("Total length", "total_length_bp"),
    ("Largest contig", "largest_contig_bp"),
    ("N50", "n50_bp"),
    ("GC (%)", "gc_percent"),
]


def parse_quast(path):
    """Return an ordered dict of {label: value} extracted from a QUAST TSV."""
    rows = {}
    with open(path, newline="") as fh:
        for line in csv.reader(fh, delimiter="\t"):
            if len(line) >= 2:
                rows[line[0].strip()] = line[1].strip()

    result = {}
    for quast_name, label in WANTED:
        # Find the first QUAST row whose name starts with the wanted metric.
        # "Total length" is preferred over "Total length (>= 1000 bp)" etc.
        match = next(
            (v for k, v in rows.items() if k == quast_name),
            None,
        )
        if match is None:
            match = next(
                (v for k, v in rows.items() if k.startswith(quast_name)),
                "NA",
            )
        result[label] = match
    return result


def main():
    ap = argparse.ArgumentParser(description="Summarise a QUAST report.tsv")
    ap.add_argument("--quast", required=True, help="path to QUAST report.tsv")
    args = ap.parse_args()

    try:
        metrics = parse_quast(args.quast)
    except FileNotFoundError:
        sys.exit(f"ERROR: QUAST report not found: {args.quast}")

    for label, value in metrics.items():
        print(f"{label}\t{value}")


if __name__ == "__main__":
    main()
