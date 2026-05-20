# Data source

This demo uses Oxford Nanopore MinION WGS reads from Bacillus subtilis strain MB9_B6.Only first 100,000 reads downloaded for this demo

- BioProject: PRJNA587401
- Experiment: SRX7091076
- Run: SRR10390699
- Organism: Bacillus subtilis
- Platform: Oxford Nanopore MinION
- Library layout: single
- Download command:

```bash
fastq-dump --gzip -X 100000 --outdir data/raw SRR10390699
