FROM ubuntu:24.04
LABEL tool=bowtie2 version=2.5.5 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install wget git g++ libz-dev cmake make zlib1g-dev \
bzip2 autoconf libncurses5-dev libbz2-dev liblzma-dev libcurl4-openssl-dev unzip -y && \
cd /usr/bin/; \
wget https://github.com/BenLangmead/bowtie2/releases/download/v2.5.5/bowtie2-2.5.5-linux-x86_64.zip && \
unzip bowtie2-2.5.5-linux-x86_64.zip && rm bowtie2-2.5.5-linux-x86_64.zip &&  \
mv ./bowtie2-2.5.5-linux-x86_64/* ./ ; \
wget https://github.com/samtools/samtools/releases/download/1.22.1/samtools-1.22.1.tar.bz2 && \
tar xvjf samtools-1.22.1.tar.bz2 && rm samtools-1.22.1.tar.bz2; \
cd samtools-1.22.1; autoheader; autoconf -Wno-syntax; ./configure; make; make install
