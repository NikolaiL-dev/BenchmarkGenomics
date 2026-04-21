#!/usr/bin/env bash

set -euo pipefail

INPUT=$1
OUTPUT=$2
REF=$(basename "$3")
REF_UNCOMPRESSED="${REF%.gz}"
REF_DIR=$(dirname "$3") 
SID=$4
SUFFIX_IN=$5
SUFFIX_OUT=$6
THREADS=$7

docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
	freebayes:1.3.10 bash -s <<EOF
set -euxo pipefail 
cut -f1 /ref/${REF_UNCOMPRESSED}.fai > /project/contigs.list

parallel -j ${THREADS} --joblog /output/log/parallel.freebayes.log '
	chr={}
	freebayes \
		--standard-filters \
		-f /ref/${REF_UNCOMPRESSED} \
		-r \${chr} \
		/input/${SID}${SUFFIX_IN}.bam \
	| bcftools view -Oz -o /project/${SID}${SUFFIX_OUT}.\${chr}.vcf.gz
	bcftools index -t /project/${SID}${SUFFIX_OUT}.\${chr}.vcf.gz
' :::: /project/contigs.list

ls -1 /project/${SID}${SUFFIX_OUT}.*.vcf.gz >  /project/vcf.list

bcftools concat -f /project/vcf.list -Oz -o /project/${SID}${SUFFIX_OUT}.vcf.gz
mv /project/${SID}${SUFFIX_OUT}.vcf.gz /output/
bcftools index -t /output/${SID}${SUFFIX_OUT}.vcf.gz
EOF
