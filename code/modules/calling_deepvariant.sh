#!/usr/bin/env bash

set -euo pipefail

INPUT=$1
OUTPUT=$2
REF=$(basename "$3")
REF_DIR=$(dirname "$3") 
SID=$4
SUFFIX_IN=$5
SUFFIX_OUT=$6
THREADS=$7

docker run --gpus all --rm -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
	google/deepvariant:1.10.0-gpu run_deepvariant \
		--model_type=WGS \
		--ref=/ref/${REF} \
		--reads=/input/${SID}${SUFFIX_IN}.bam \
		--par_regions_bed=/ref/par/hg38.par.bed \
		--output_vcf /output/${SID}${SUFFIX_OUT}.vcf \
		--num_shards ${THREADS} \
		--logging_dir /output/log/
