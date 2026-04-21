#!/usr/bin/env bash
set -euo pipefail

INPUT=$1
OUTPUT=$2
SID=$3
SUFFIX_IN=$4
SUFFIX_OUT=$5
THREADS=$6

docker run --rm -v "${INPUT}:/project/fq" -v "${OUTPUT}:/project/trimmed/" \
	fastp:1.0.1 fastp\
		--in1 /project/fq/${SID}_R1${SUFFIX_IN}.fastq.gz \
		--in2 /project/fq/${SID}_R2${SUFFIX_IN}.fastq.gz \
		--out1 /project/trimmed/${SID}_R1${SUFFIX_OUT}.fastq.gz \
		--out2 /project/trimmed/${SID}_R2${SUFFIX_OUT}.fastq.gz \
		--thread ${THREADS} \
		--json /project/trimmed/log/${SID}${SUFFIX_OUT}.json \
		--compression 1 \
		--length_required 125
