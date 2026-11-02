# Fedora release to build against. Must match the kinoite-main tag AND the akmods tag.
ARG FEDORA_VERSION=44

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Prebuilt, signed kmods (incl. ryzen-smu) for Fedora's stock kernel
FROM ghcr.io/ublue-os/akmods-extra:main-${FEDORA_VERSION} AS akmods-extra

# Base Image
FROM ghcr.io/ublue-os/kinoite-main:${FEDORA_VERSION}

### [IM]MUTABLE /opt
## Uncomment the following line if you want /opt to be immutable and usable
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Modify build.sh to install packages and make other customizations.
## The akmods RPMs are mounted at /akmods (not /tmp, since /tmp is a tmpfs here).

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods-extra,source=/rpms,target=/akmods \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint