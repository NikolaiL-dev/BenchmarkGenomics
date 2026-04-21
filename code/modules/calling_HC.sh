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
HC_CORES=$((${THREADS} / 2))
RAM=$8
RAM_START=$9

docker run --rm -i -v "${INPUT}:/input/" -v "${OUTPUT}:/output/" -v "${REF_DIR}:/ref/" \
	gatk:4.6.2.0 bash -s <<EOF

set -euxo pipefail
mkdir -p /project/
mkdir -p /output/tmp_hc/bqsr/
cut -f1 /ref/${REF}.fai > /project/contigs.list

if [ ! -f /input/${SID}${SUFFIX_IN}.bqsr.bam ]; then

	parallel -j ${THREADS} --joblog /input/log/parallel${SUFFIX_IN}.bqsr.log '
		chr={}
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" BaseRecalibrator \
			-R /ref/${REF} \
			-I /input/${SID}${SUFFIX_IN}.bam \
			-L \${chr} \
			--known-sites /ref/truthset/Homo_sapiens_assembly38.dbsnp138.vcf \
			--known-sites /ref/truthset/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
			--known-sites /ref/truthset/Homo_sapiens_assembly38.known_indels.vcf.gz \
			-O /output/tmp_hc/bqsr/${SID}${SUFFIX_IN}.\${chr}.recal.table
	' :::: /project/contigs.list

	ls -1 /output/tmp_hc/bqsr/${SID}${SUFFIX_IN}.*.recal.table > /project/BQSR.list
	gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" GatherBQSRReports \
		\$(sed "s#^#-I #g" /project/BQSR.list) \
		-O /output/tmp_hc/bqsr/${SID}${SUFFIX_IN}.recal.table

	gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" ApplyBQSR \
		-R /ref/${REF} \
		-I /input/${SID}${SUFFIX_IN}.bam \
		-bqsr /output/tmp_hc/bqsr/${SID}${SUFFIX_IN}.recal.table \
		-O /input/${SID}${SUFFIX_IN}.bqsr.bam
fi

for BAM in /input/${SID}${SUFFIX_IN}.bqsr.bam /input/${SID}${SUFFIX_IN}.bam
do
	mkdir -p /output/tmp_hc/bqsr/
	if [[ \${BAM} == *"bqsr"* ]]; then
  		BQSR_SUFFIX=".bqsr"
  	else
  		BQSR_SUFFIX=""
	fi
	
	if [ ! -f /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz ]; then
		#             - - - > run parallel < - - -
		parallel -j ${HC_CORES} --joblog /output/log/parallel${SUFFIX_IN}\${BQSR_SUFFIX}.HC.log '
			chr={1}
			BAM={2}
			BQSR_SUFFIX={3}
			gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g"  HaplotypeCaller \
				-R /ref/${REF} \
				-I \${BAM} \
				-L \${chr} \
				--native-pair-hmm-threads 2 \
				-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.\${chr}.HC.vcf.gz
			gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" IndexFeatureFile \
				-I /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.\${chr}.HC.vcf.gz
		' ::: \$(cat /project/contigs.list) ::: \${BAM} ::: \${BQSR_SUFFIX}
		
		ls -1 /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.*.HC.vcf.gz >  /project/vcf.list
		
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" MergeVcfs \
			\$(sed "s#^#-I #g" /project/vcf.list) \
			-O /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz
		
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" IndexFeatureFile \
			-I /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz
	fi
	
	#                        - - - > VQSR < - - -
	if [ ! -f /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vqsr.vcf.gz ]; then
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" VariantRecalibrator \
			-V /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz \
			--trust-all-polymorphic \
			-tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.5 -tranche 99.0 \
			-tranche 97.0 -tranche 96.0 -tranche 95.0 -tranche 94.0 -tranche 93.5 \
			-tranche 93.0 -tranche 92.0 -tranche 91.0 -tranche 90.0 \
			-an FS -an ReadPosRankSum -an MQRankSum -an QD -an SOR -an DP \
			-mode INDEL \
			--max-gaussians 4 \
			--resource:mills,known=false,training=true,truth=true,prior=12 /ref/truthset/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
			--resource:axiomPoly,known=false,training=true,truth=false,prior=10 /ref/truthset/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz \
			--resource:dbsnp,known=true,training=false,truth=false,prior=2 /ref/truthset/Homo_sapiens_assembly38.dbsnp138.vcf \
			-O /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indels.recal \
			--tranches-file /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indels.tranches
		
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" VariantRecalibrator \
			-V /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz \
			--trust-all-polymorphic \
			-tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 -tranche 99.6 -tranche 99.5 \
			-tranche 99.4 -tranche 99.3 -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 \
			-an QD -an MQRankSum -an ReadPosRankSum -an FS -an MQ -an SOR -an DP \
			-mode SNP \
			--max-gaussians 6 \
			-resource:hapmap,known=false,training=true,truth=true,prior=15 /ref/truthset/hapmap_3.3.hg38.vcf.gz \
			-resource:omni,known=false,training=true,truth=true,prior=12 /ref/truthset/1000G_omni2.5.hg38.vcf.gz \
			-resource:1000G,known=false,training=true,truth=false,prior=10 /ref/truthset/1000G_phase1.snps.high_confidence.hg38.vcf.gz \
			-resource:dbsnp,known=true,training=false,truth=false,prior=7 /ref/truthset/Homo_sapiens_assembly38.dbsnp138.vcf \
			-O /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.recal \
			--tranches-file /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.tranches
		
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" ApplyVQSR \
			-V /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz \
			--recal-file /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indels.recal \
			--tranches-file /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indels.tranches \
			--truth-sensitivity-filter-level 99.7 \
			--create-output-variant-index true \
			-mode INDEL \
			-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indel.vqsr.vcf.gz
			
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" ApplyVQSR \
			-V /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indel.vqsr.vcf.gz \
			--recal-file /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.recal \
			--tranches-file /project/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.tranches \
			--truth-sensitivity-filter-level 99.7 \
			--create-output-variant-index true \
			-mode SNP \
			-O /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vqsr.vcf.gz
	fi
	#                        - - - > CNN_D1 < - - -
	if [ ! -f /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.CNN1D.vcf.gz ]; then
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" NVScoreVariants \
			-R /ref/${REF_UNCOMPRESSED} \
			-V /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz \
			-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.CNN1.vcf.gz \
			-tensor-type reference
			
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" IndexFeatureFile \
			-I /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.CNN1.vcf.gz
			
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" FilterVariantTranches \
			-V /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.CNN1.vcf.gz \
			--output /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.CNN1D.vcf.gz \
			--info-key CNN_1D \
			--snp-tranche 99.9 \
			--indel-tranche 99.0 \
			--resource /ref/truthset/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
			--resource /ref/truthset/1000G_phase1.snps.high_confidence.hg38.vcf.gz \
			--resource /ref/truthset/hapmap_3.3.hg38.vcf.gz
	fi
	#                        - - - > VariantFiltration < - - -
	if [ ! -f /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.filtered.vcf.gz ]; then
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" SelectVariants \
			-V /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz \
			-select-type SNP \
			-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.vcf.gz
		    
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" SelectVariants \
			-V /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.vcf.gz \
			-select-type INDEL \
			-select-type MIXED \
			-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indel.vcf.gz
		    
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" VariantFiltration \
			-V /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.vcf.gz \
			-filter "QD < 2.0" --filter-name "QD2" \
			-filter "QUAL < 30.0" --filter-name "QUAL30" \
			-filter "SOR > 3.0" --filter-name "SOR3" \
			-filter "FS > 60.0" --filter-name "FS60" \
			-filter "MQ < 40.0" --filter-name "MQ40" \
			-filter "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
			-filter "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
			-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.filtered.vcf.gz
			
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" VariantFiltration \
			-V /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indel.vcf.gz \
			-filter "QD < 2.0" --filter-name "QD2" \
			-filter "QUAL < 30.0" --filter-name "QUAL30" \
			-filter "FS > 200.0" --filter-name "FS200" \
			-filter "ReadPosRankSum < -20.0" --filter-name "ReadPosRankSum-20" \
			-O /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indel.filtered.vcf.gz
		
		gatk --java-options "-Xms${RAM_START}g -Xmx${RAM}g" MergeVcfs \
			-I /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.snp.filtered.vcf.gz \
			-I /output/tmp_hc/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.indel.filtered.vcf.gz \
			-O /output/${SID}${SUFFIX_IN}\${BQSR_SUFFIX}.HC.filtered.vcf.gz
	fi
	rm -rf  /output/tmp_hc/
done
touch /output/${SID}${SUFFIX_OUT}.finished
EOF
