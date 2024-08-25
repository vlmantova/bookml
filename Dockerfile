### TeX Live base image must be Debian-based
ARG LATEXML=ghcr.io/vlmantova/bookml-latexml:0.8.8-tl2021

### BookML
FROM $LATEXML

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
