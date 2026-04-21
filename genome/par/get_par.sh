#!/usr/bin/env bash
wget https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/references/GRCh38/resources/hg38.par.bed.gz
wget https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/references/GRCh38/resources/hg38.par.bed.gz.tbi
gunzip --stdout hg38.par.bed.gz > hg38.par.bed
gunzip --stdout --suffix=.gz.tbi hg38.par.bed.gz.tbi > hg38.par.bed.tbi
rm hg38.par.bed.gz hg38.par.bed.gz.tbi
