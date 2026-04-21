FROM ubuntu:24.04
LABEL tool=FASTP version=v1.0.1 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install wget git cmake make g++ autoconf libtool nasm help2man libfl-dev libisal-dev -y; \
mkdir dependencies; cd dependencies; \
git clone https://github.com/intel/isa-l.git; cd isa-l; ./autogen.sh; ./configure --prefix=/usr --libdir=/usr/lib64; make -j; make install; cd .. ; \
git clone https://github.com/ebiggers/libdeflate.git; cd libdeflate; cmake -B build; cmake --build build; cmake --install build; cd ../.. ; \
wget https://github.com/OpenGene/fastp/archive/refs/tags/v1.0.1.tar.gz; tar -xvzf v1.0.1.tar.gz; rm v1.0.1.tar.gz; cd fastp-1.0.1; make -j; make install
