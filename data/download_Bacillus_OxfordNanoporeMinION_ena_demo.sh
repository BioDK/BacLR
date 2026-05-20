#!/usr/bin/env bash
set -euo pipefail

# Download the first 100,000 reads from an ENA FASTQ file
# Dataset: Bacillus subtilis ONT run SRR10390699

RUN="SRR10390699"
SAMPLE="bsubtilis_MB9_B6_ONT_100k"

N_READS=100000
N_LINES=$((N_READS * 4))

RAW_DIR="data/raw"
LOG_DIR="logs"
META_FILE="${RAW_DIR}/${RUN}_ena_files.tsv"
OUT_FILE="${RAW_DIR}/${SAMPLE}.fastq.gz"

mkdir -p "${RAW_DIR}" "${LOG_DIR}"

echo "[1/5] Checking required commands..."

for cmd in curl awk gunzip gzip head wc; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "ERROR: '${cmd}' is not installed or not available in PATH."
        exit 1
    fi
done

echo "[2/5] Querying ENA metadata for ${RUN}..."

curl -fsSL \
  "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${RUN}&result=read_run&fields=run_accession,fastq_ftp,fastq_md5,fastq_bytes&format=tsv" \
  -o "${META_FILE}"

echo "ENA metadata:"
cat "${META_FILE}"

FASTQ_FTP=$(awk 'NR==2 {split($2,a,";"); print a[1]}' "${META_FILE}")

if [[ -z "${FASTQ_FTP}" ]]; then
    echo "ERROR: Could not find FASTQ FTP link in ENA metadata."
    echo "Please check ${META_FILE}"
    exit 1
fi

FASTQ_URL="https://${FASTQ_FTP}"

echo "[3/5] FASTQ URL found:"
echo "${FASTQ_URL}"

echo "[4/5] Downloading first ${N_READS} reads..."
echo "Output: ${OUT_FILE}"

# Note:
# FASTQ format uses 4 lines per read.
# 100,000 reads = 400,000 lines.
#
# set +o pipefail is used temporarily because 'head' stops early,
# which can make curl/gunzip report a broken pipe even when the subset is created correctly.

set +o pipefail
curl -L "${FASTQ_URL}" 2> "${LOG_DIR}/${RUN}.curl.log" \
  | gunzip -c \
  | head -n "${N_LINES}" \
  | gzip -c \
  > "${OUT_FILE}"
set -o pipefail

echo "[5/5] Checking downloaded file..."

if [[ ! -s "${OUT_FILE}" ]]; then
    echo "ERROR: Output file is empty or missing: ${OUT_FILE}"
    exit 1
fi

ACTUAL_LINES=$(gunzip -c "${OUT_FILE}" | wc -l | awk '{print $1}')
ACTUAL_READS=$((ACTUAL_LINES / 4))

echo "Downloaded file:"
ls -lh "${OUT_FILE}"

echo "Lines: ${ACTUAL_LINES}"
echo "Reads: ${ACTUAL_READS}"

if [[ "${ACTUAL_READS}" -lt 1000 ]]; then
    echo "ERROR: Too few reads downloaded. Please inspect logs."
    exit 1
fi

echo "Done."
echo "FASTQ subset saved to: ${OUT_FILE}"
