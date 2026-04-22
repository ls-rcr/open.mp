FROM ubuntu:22.04
RUN \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        cmake \
        ninja-build \
        clang-11 \
        python3-pip \
        gcc-9-multilib \
        g++-9-multilib \
        libstdc++-11-dev:i386 \
    && \
    useradd -m user && \
    su user -c 'pip3 install --user -v "conan==1.57.0"'

COPY docker-entrypoint.sh /
RUN sed -i 's/\r$//' /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh

USER user

ENV CC=/usr/bin/clang-11 \
    CXX=/usr/bin/clang++-11 \
    PATH=~/.local/bin:${PATH}

CMD /docker-entrypoint.sh
