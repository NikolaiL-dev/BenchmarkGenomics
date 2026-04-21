FROM ubuntu:24.04
LABEL tool=freebayes version=1.3.10 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install make lbzip2 zlib1g-dev libgsl-dev libperl-dev libbz2-dev liblzma-dev gcc autoconf libcurl4-openssl-dev libssl-dev tar wget gzip parallel -y && \
cd /usr/local/bin && \
wget https://github.com/samtools/bcftools/releases/download/1.23/bcftools-1.23.tar.bz2 && \
tar -xf bcftools-1.23.tar.bz2 && rm bcftools-1.23.tar.bz2 && \
cd bcftools-1.23 && \
./configure && \
make && \
cd .. && \
mv ./bcftools-1.23/* ./ && \
\
wget https://github.com/freebayes/freebayes/releases/download/v1.3.10/freebayes-1.3.10-linux-amd64-static.gz && \
gunzip freebayes-1.3.10-linux-amd64-static.gz && \
chmod +x ./freebayes-1.3.10-linux-amd64-static && \
mv freebayes-1.3.10-linux-amd64-static freebayes
