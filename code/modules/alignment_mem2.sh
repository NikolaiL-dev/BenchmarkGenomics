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

if [[ ${SUFFIX_IN} == *"fastpMERGE"* ]]; then
	docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
		bwa-mem2:2.3 bash -s <<EOF
set -euxo pipefail
bwa-mem2 mem \
	-t ${THREADS} \
	-M \
	-R "@RG\tID:${SID}\tSM:${SID}\tLB:TruSeqPCRFree\tPL:ILLUMINA" \
	/ref/${REF} \
	/input/${SID}_R1${SUFFIX_IN}.fastq.gz \
	/input/${SID}_R2${SUFFIX_IN}.fastq.gz 2> /output/log/${SID}${SUFFIX_OUT}.PE.log | \
samtools sort -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.tmp1.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.tmp1.bam
bwa-mem2 mem \
	-t ${THREADS} \
	-M \
	-R "@RG\tID:${SID}\tSM:${SID}\tLB:TruSeqPCRFree\tPL:ILLUMINA" \
	/ref/${REF} \
	/input/${SID}${SUFFIX_IN}.fastq.gz 2> /output/log/${SID}${SUFFIX_OUT}.SE.log | \
samtools sort -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.tmp2.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.tmp2.bam
samtools merge -c -p -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.bam /output/${SID}${SUFFIX_OUT}.tmp1.bam /output/${SID}${SUFFIX_OUT}.tmp2.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.bam
rm /output/*.tmp1.bam /output/*.tmp2.bam /output/*.tmp1.bam.bai /output/*.tmp2.bam.bai
touch /output/${SID}${SUFFIX_OUT}.finished
EOF
else
	docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
		bwa-mem2:2.3 bash -s <<EOF
bwa-mem2 mem \
	-t ${THREADS} \
	-M \
	-R "@RG\tID:${SID}\tSM:${SID}\tLB:TruSeqPCRFree\tPL:ILLUMINA" \
	/ref/${REF} \
	/input/${SID}_R1${SUFFIX_IN}.fastq.gz \
	/input/${SID}_R2${SUFFIX_IN}.fastq.gz  2> /output/log/${SID}${SUFFIX_OUT}.log | \
samtools sort -@ ${THREADS} -o /output/${SID}${SUFFIX_OUT}.bam
samtools index -@ ${THREADS} /output/${SID}${SUFFIX_OUT}.bam
touch /output/${SID}${SUFFIX_OUT}.finished
EOF
fi
