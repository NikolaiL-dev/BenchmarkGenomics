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

docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
	strelka:2.9.10 bash -s <<EOF
set -euxo pipefail 
cp /ref/par/ploidy.vcf /project/
sed -i "s/__SAMPLE__/${SID}/g" /project/ploidy.vcf
bgzip /project/ploidy.vcf
tabix --preset vcf /project/ploidy.vcf.gz

mkdir -p /project/workspace
python2 /project/strelka-2.9.10.centos6_x86_64/bin/configureStrelkaGermlineWorkflow.py \
	--bam /input/${SID}${SUFFIX_IN}.bam \
	--referenceFasta /ref/${REF} \
	--runDir /project/workspace/ \
	--ploidy /project/ploidy.vcf.gz

python2 /project/workspace/runWorkflow.py -m local -j ${THREADS}
cp /project/workspace/results/variants/variants.vcf.gz /output/${SID}${SUFFIX_OUT}.vcf.gz
EOF
