FROM ubuntu:24.04
LABEL tool=bwa-mem2 version=v2.3 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install wget git g++ libz-dev cmake make zlib1g-dev \
bzip2 autoconf libncurses5-dev libbz2-dev liblzma-dev libcurl4-openssl-dev -y; \
cd /usr/bin/; \
wget https://github.com/bwa-mem2/bwa-mem2/releases/download/v2.3/bwa-mem2-2.3_x64-linux.tar.bz2; \
tar -xf bwa-mem2-2.3_x64-linux.tar.bz2; rm bwa-mem2-2.3_x64-linux.tar.bz2;  \
mv ./bwa-mem2-2.3_x64-linux/* ./; \
wget https://github.com/samtools/samtools/releases/download/1.22.1/samtools-1.22.1.tar.bz2; \
tar xvjf samtools-1.22.1.tar.bz2; rm samtools-1.22.1.tar.bz2; \
cd samtools-1.22.1; autoheader; autoconf -Wno-syntax; ./configure; make; make install
