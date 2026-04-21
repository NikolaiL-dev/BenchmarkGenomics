FROM ubuntu:24.04
LABEL tool=bbmap version=39.79 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install wget default-jre -y; \
wget -O BBTools-39.79.tar.gz https://github.com/bbushnell/BBTools/archive/refs/tags/v39.79.tar.gz; \
tar -xvzf BBTools-39.79.tar.gz; rm BBTools-39.79.tar.gz

