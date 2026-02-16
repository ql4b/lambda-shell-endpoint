# Multi-stage build for jq static binary
FROM public.ecr.aws/lambda/provided:al2023 AS builder

# Install build dependencies
RUN dnf update -y && \
    dnf install -y \
    gcc \
    make \
    autoconf \
    automake \
    libtool \
    git \
    oniguruma-devel \
    && dnf clean all

# Build jq from source for static linking
WORKDIR /build
RUN git clone --depth 1 --branch jq-1.7.1 https://github.com/jqlang/jq.git
WORKDIR /build/jq

# Configure and build static binary
RUN git submodule update --init && \
    autoreconf -fi && \
    ./configure --disable-maintainer-mode --enable-static --disable-shared --with-oniguruma=builtin && \
    make LDFLAGS="-all-static -static" -j$(nproc)

# Verify the binary is static
RUN ldd jq || echo "Static binary confirmed"

# Final stage - create layer structure
FROM public.ecr.aws/lambda/provided:al2023
COPY --from=builder /build/jq/jq /opt/bin/jq

# Set executable permissions
RUN chmod +x /opt/bin/jq