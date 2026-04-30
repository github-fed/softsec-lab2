FROM aflplusplus/aflplusplus:latest

# Build with optional packages (in README)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libpng-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

# Copy relevant files into container
COPY . /lab

RUN git clone https://github.com/saitoha/libsixel.git && \
    cd libsixel && \
    git checkout v1.8.6

# Build 1: White-box (we can try afl-clang-lto)
RUN cd libsixel && \
    make distclean || true && \
    CC=afl-clang-lto \
    CFLAGS="-fsanitize=address -g -O1" \
    LDFLAGS="-fsanitize=address" \
    ./configure --disable-shared --disable-python --prefix=/lab/libsixel-inst && \
    make -j$(nproc) && \
    make install

# Build 2:  Black-box/QEMU
RUN cd libsixel && \
    make distclean && \
    CC=clang \
    CFLAGS="-g -O1" \
    ./configure --disable-shared --disable-python --prefix=/lab/libsixel-vanilla && \
    make -j$(nproc) && \
    make install

# Generate seed corpus and create artifact directories
RUN python3 /lab/seeds/gen_seeds.py && \
    mkdir -p /lab/findings /lab/findings-qemu

ENTRYPOINT ["/bin/bash"]