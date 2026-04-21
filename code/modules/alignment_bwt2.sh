#!/usr/bin/env bash
set -euo pipefail

INPUT=$1
OUTPUT=$2
REF=$(basename "$3")
REF_PREFIX="${REF%.fasta.gz}"
REF_DIR=$(dirname "$3")
SID=$4
SUFFIX_IN=$5
SUFFIX_OUT=$6
THREADS=$7

if [[ ${SUFFIX_IN} == *"fastpMERGE"* ]]; then
	docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
		bowtie2:2.5.5  bash -s <<EOF
set -euxo pipefail
if [ ! -f /output/${SID}${SUFFIX_OUT}.tmp1.bam ]; then
	bowtie2 \
		--threads ${THREADS} \
		--end-to-end \
		--very-sensitive \
		--rg-id ${SID} \
		--rg "SM:${SID}" \
		--rg "LB:TruSeqPCRFree" \
		--rg "PL:ILLUMINA" \
		-1 /input/${SID}_R1${SUFFIX_IN}.fastq.gz \
		-2 /input/${SID}_R2${SUFFIX_IN}.fastq.gz \
		-x /ref/${REF_PREFIX} | \
	samtools sort -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.tmp1.bam
	samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.tmp1.bam
fi
if [ ! -f /output/${SID}${SUFFIX_OUT}.tmp2.bam ]; then
bowtie2 \
	--threads ${THREADS} \
	--end-to-end \
	--very-sensitive \
	--rg-id ${SID} \
	--rg "SM:${SID}" \
	--rg "LB:TruSeqPCRFree" \
	--rg "PL:ILLUMINA" \
	-U /input/${SID}${SUFFIX_IN}.fastq.gz \
	-x /ref/${REF_PREFIX} | \
samtools sort -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.tmp2.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.tmp2.bam
fi
samtools merge -c -p -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.bam /output/${SID}${SUFFIX_OUT}.tmp1.bam /output/${SID}${SUFFIX_OUT}.tmp2.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.bam
rm /output/*.tmp1.bam /output/*.tmp2.bam /output/*.tmp1.bam.bai /output/*.tmp2.bam.bai
touch /output/${SID}${SUFFIX_OUT}.finished
EOF
else
	docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
		bowtie2:2.5.5  bash -s <<EOF
set -euxo pipefail 
bowtie2 \
	--threads ${THREADS} \
	--end-to-end \
	--very-sensitive \
	--rg-id ${SID} \
	--rg "SM:${SID}" \
	--rg "LB:TruSeqPCRFree" \
	--rg "PL:ILLUMINA" \
	-1 /input/${SID}_R1${SUFFIX_IN}.fastq.gz \
	-2 /input/${SID}_R2${SUFFIX_IN}.fastq.gz \
	-x /ref/${REF_PREFIX} | \
samtools sort -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.bam
touch /output/${SID}${SUFFIX_OUT}.finished
EOF
fi
