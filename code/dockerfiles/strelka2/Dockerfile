FROM ubuntu:24.04
LABEL tool=strelka version=2.9.10 contributor=Nikolai email=nikolay.lebedev.bit@gmail.com
WORKDIR /project

RUN apt-get update && apt-get install g++ make tabix wget lbzip2 -y; \
\
wget https://github.com/Illumina/strelka/releases/download/v2.9.10/strelka-2.9.10.centos6_x86_64.tar.bz2; \
tar -xf strelka-2.9.10.centos6_x86_64.tar.bz2; rm strelka-2.9.10.centos6_x86_64.tar.bz2; \
\
wget https://github.com/Illumina/manta/releases/download/v1.6.0/manta-1.6.0.centos6_x86_64.tar.bz2; \
tar -xf manta-1.6.0.centos6_x86_64.tar.bz2; rm manta-1.6.0.centos6_x86_64.tar.bz2; \
\
wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz; \
tar -xzf Python-2.7.18.tgz; rm Python-2.7.18.tgz; \
cd Python-2.7.18; ./configure --enable-optimizations; \
make altinstall; ln -s "/usr/local/bin/python2.7" "/usr/bin/python2"
