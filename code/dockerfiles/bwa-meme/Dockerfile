FROM ubuntu:24.04
LABEL tool=bwa-meme version=v1.0.6 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install wget git g++ libz-dev cmake make zlib1g-dev \
bzip2 autoconf libncurses5-dev libbz2-dev liblzma-dev libcurl4-openssl-dev -y; \
cd /usr/bin/; \
wget https://github.com/kaist-ina/BWA-MEME/archive/refs/tags/v1.0.6.tar.gz; \
tar xvzf v1.0.6.tar.gz; rm v1.0.6.tar.gz; \
cd BWA-MEME-1.0.6; make -j; mv * ../ ; cd ..; \
wget https://github.com/samtools/samtools/releases/download/1.22.1/samtools-1.22.1.tar.bz2 && \
tar xvjf samtools-1.22.1.tar.bz2 && rm samtools-1.22.1.tar.bz2; \
cd samtools-1.22.1; autoheader; autoconf -Wno-syntax; ./configure; make; make install
