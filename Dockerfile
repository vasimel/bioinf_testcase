FROM ubuntu:22.04


# set packages version:
# HTSLIB 1.20 (16/04/2024)
ARG HTSLIB_VERSION=1.20
# LIBDEFLATE 1.20 (23/03/2024)
ARG LIBDEFLATE_VERSION=v1.20
# SAMTOOLS 1.20 (16/04/2024)
ARG SAMTOOLS_VERSION=1.20
# SAMTOOLS 1.20 (16/04/2024)
ARG BCFTOOLS_VERSION=1.20
# VCFTOOLS v0.1.16 (03/08/2018)
ARG VCFTOOLS_VERSION=v0.1.16


# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV SOFT=/soft
ENV HTSLIB_VERSION=${HTSLIB_VERSION}
ENV LIBDEFLATE_VERSION=${LIBDEFLATE_VERSION}
ENV SAMTOOLS_VERSION=${SAMTOOLS_VERSION}
ENV BCFTOOLS_VERSION=${BCFTOOLS_VERSION}
ENV VCFTOOLS_VERSION=${VCFTOOLS_VERSION}



# Update the package list and install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    pkg-config \
    libncurses5-dev \
    libbz2-dev \
    zlib1g-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libffi-dev \
    libtool \
    autoconf \
    automake \
    cmake \
    git \
    python3 \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install argparse pysam

# Create directories
RUN mkdir -p $SOFT

# Install samtools, htslib, and libdeflate from source
WORKDIR /tmp
RUN git clone https://github.com/samtools/htslib.git \
    && cd htslib \
    && git checkout ${HTSLIB_VERSION} \
    && autoreconf -i \
    && git submodule update --init --recursive \
    && ./configure --prefix=$SOFT/htslib-$HTSLIB_VERSION \
    && make \
    && make install

ENV HTSLIB_DIR=$SOFT/htslib-$HTSLIB_VERSION/


RUN git clone https://github.com/samtools/samtools.git \
    && cd samtools \
    && git checkout $SAMTOOLS_VERSION \
    && autoheader \
    && autoconf -Wno-syntax \
    && ./configure --prefix=$SOFT/samtools-$SAMTOOLS_VERSION --with-htslib=$HTSLIB_DIR \
    && make \
    && make install

ENV SAMTOOLS_DIR=$SOFT/samtools-${SAMTOOLS_VERSION}/


RUN git clone https://github.com/ebiggers/libdeflate.git \
    && cd libdeflate \
    && git checkout $LIBDEFLATE_VERSION \
    && mkdir -p build \
    && cmake -B build -DCMAKE_INSTALL_PREFIX=$SOFT/libdeflate-$LIBDEFLATE_VERSION \
    && cmake --build build \
    && cmake --install build

ENV LIBDEFLATE_DIR=$SOFT/libdeflate-$LIBDEFLATE_VERSION

# Install bcftools from source
RUN git clone https://github.com/samtools/bcftools.git \
    && cd bcftools \
    && git checkout $BCFTOOLS_VERSION \
    && make \
    && make install prefix=$SOFT/bcftools-$BCFTOOLS_VERSION


ENV BCFTOOLS_DIR=$SOFT/bcftools-$BCFTOOLS_VERSION

# Install vcftools from source
RUN git clone https://github.com/vcftools/vcftools.git \
    && cd vcftools \
    && git checkout $VCFTOOLS_VERSION \
    && ./autogen.sh \
    && ./configure --prefix=$SOFT/vcftools-$VCFTOOLS_VERSION \
    && make \
    && make install

ENV VCFTOOLS_DIR=$SOFT/vcftools-$VCFTOOLS_VERSION

# Set PATH
ENV PATH="${SAMTOOLS_DIR}/bin:${BCFTOOLS_DIR}/bin:${VCFTOOLS_DIR}/bin:${HTSLIB_DIR}/bin:${LIBDEFLATE_DIR}/bin:$PATH"
ENV LD_LIBRARY_PATH="${HTSLIB_DIR}/lib:$LD_LIBRARY_PATH"


# Clean up
WORKDIR /
RUN rm -rf /tmp/*


# Copy the necessary files
COPY ./twoAllel_to_refAlt.py $SOFT

RUN mkdir -p /data

COPY ./FP_SNPs_10k_GB38_twoAllelsFormat.tsv /data
COPY ./FP_SNPs.txt /data

# Default command
CMD ["bash"]
