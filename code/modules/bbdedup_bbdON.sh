#!/usr/bin/env bash
set -euo pipefail

INPUT=$1
OUTPUT=$2
SID=$3
SUFFIX_IN=$4
SUFFIX_OUT=$5
THREADS=$6
RAM=$7
RAM_START=$8

docker run --rm -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" \
	broadinstitute/gatk:4.6.2.0 gatk --java-options "-Xmx${RAM}g -Xms${RAM_START}g" MarkDuplicates \
		--INPUT /input/${SID}${SUFFIX_IN}.bam \
		--OUTPUT /output/${SID}${SUFFIX_OUT}.bam \
		--CREATE_INDEX true \
		--METRICS_FILE /output/log/${SID}${SUFFIX_OUT}.log
touch ${OUTPUT}/${SID}${SUFFIX_OUT}.finished
