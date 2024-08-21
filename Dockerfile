### TeX Live base image must be Debian-based
ARG TEXLIVE=ghcr.io/vlmantova/bookml-texlive:2021

FROM $TEXLIVE AS latexml
ARG DEBIAN_FRONTEND=noninteractive
RUN set -ex && apt-get update -qq && apt-get install -qy curl ghostscript imagemagick latexml --no-install-recommends
RUN set -ex && curl -L https://launchpad.net/ubuntu/+archive/primary/+files/latexml_0.8.8-1_all.deb -o /latexml_0.8.8-1_all.deb
RUN set -ex && dpkg -i /latexml_0.8.8-1_all.deb || apt -f install && rm /latexml_0.8.8-1_all.deb

# Enable imagemagick policy permissions for work with arXiv PDF/EPS files
# Extend imagemagick resource allowance to be able to create with high-quality images
RUN perl -pi.bak -e 's/rights="none" pattern="([XE]?PS\d?|PDF)"/rights="read|write" pattern="$1"/g;' \
  -e 's/policy domain="resource" name="width" value="(\w+)"/policy domain="resource" name="width" value="126KP"/;' \
  -e 's/policy domain="resource" name="height" value="(\w+)"/policy domain="resource" name="height" value="126KP"/;' \
  -e 's/policy domain="resource" name="area" value="(\w+)"/policy domain="resource" name="area" value="2GiB"/;' \
  -e 's/policy domain="resource" name="disk" value="(\w+)"/policy domain="resource" name="disk" value="8GiB"/;' \
  -e 's/policy domain="resource" name="memory" value="(\w+)"/policy domain="resource" name="memory" value="2GiB"/;' \
  -e 's/policy domain="resource" name="map" value="(\w+)"/policy domain="resource" name="map" value="2GiB"/;' \
  /etc/ImageMagick-6/policy.xml

ENV MAGICK_DISK_LIMIT=2GiB \
  MAGICK_MEMORY_LIMIT=512MiB \
  MAGICK_MAP_LIMIT=1GiB \
  MAGICK_TIME_LIMIT=900 \
  MAGICK_TMPDIR=/dev/shm \
  TMPDIR=/dev/shm

### BookML
FROM latexml AS bookml

ARG DEBIAN_FRONTEND=noninteractive
RUN set -ex && apt-get update -qq && apt-get -qy install \
  make \
  unzip \
  zip

COPY release.zip /release.zip

ARG BOOKML_VERSION
LABEL org.opencontainers.image.source=https://github.com/vlmantova/bookml
LABEL org.opencontainers.image.title="BookML runner"
LABEL org.opencontainers.image.licenses=GPL-3.0-or-later
LABEL org.opencontainers.image.version=$BOOKML_VERSION
LABEL org.opencontainers.image.description="Run BookML in the current working directory. Usage: `docker run -t -v.:/source ghcr.io/vlmantova/bookml:$BOOKML_VERSION`"

COPY --chmod=755 <<EOF /run-bookml
#!/usr/bin/bash
set -euo pipefail
if [[ \${1-} == update ]] ; then
  [[ -d bookml ]] && rm -fr bookml
  unzip /release.zip
  exit 0
elif [[ -d bookml ]] ; then
  make -q BOOKML_VERSION="$BOOKML_VERSION" -f bookml/bookml.mk check-for-update || echo 'BookML update available, run `update` to install it'
else
  unzip /release.zip
fi
[[ -f GNUmakefile || -f Makefile ]] || cp bookml/GNUmakefile GNUmakefile
exec make "\$@"
EOF

WORKDIR /source
ENTRYPOINT ["/run-bookml"]
