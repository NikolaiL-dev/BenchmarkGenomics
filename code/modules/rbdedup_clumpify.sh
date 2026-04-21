#!/usr/bin/env bash
set -euo pipefail

INPUT=$1
OUTPUT=$2
SID=$3
SUFFIX=$4
THREADS=$5
RAM=$6
RAM_START=$7

docker run --rm -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" \
	bbmap:39.79 BBTools-39.79/clumpify.sh  -Xmx${RAM}g -Xms${RAM_START}g \
		in=/input/${SID}_R1.fastq.gz \
		in2=/input/${SID}_R2.fastq.gz \
		out=/output/${SID}_R1${SUFFIX}.fastq.gz \
		out2=/output/${SID}_R2${SUFFIX}.fastq.gz \
		subs=0 \
		optical=t \
		dupedist=2500 \
		dedupe=t \
		threads=4
