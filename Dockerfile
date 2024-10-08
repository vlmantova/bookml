### TeX Live base layers
ARG TEXLIVE_SCHEME=small
ARG LATEXML_VERSION=0.8.8
# freeze Ubuntu version to minimize rebuilds
FROM ubuntu:24.04@sha256:b359f1067efa76f37863778f7b6d0e8d911e3ee8efa807ad01fbf5dc1ef9006b AS base

# equivs brings in a lot of dependencies, unfortunately
ARG DEBIAN_FRONTEND=noninteractive
# dependencies copied from Docker TeX Live images
RUN set -ex && apt update -qq && apt install -qy tzdata curl perl-modules && apt install -qy equivs ghostscript libgetopt-long-descriptive-perl libdigest-perl-md5-perl libncurses6 libunicode-linebreak-perl libfile-homedir-perl libyaml-tiny-perl ghostscript libsm6 python3 python3-pygments gnuplot-nox libglut3.12 --no-install-recommends

# TL 2021 is the latest version for which expl3 loads in reasonable time
ARG TEXLIVE_VERSION=2021

# install fake texlive-local package
RUN set -ex && curl -L "https://wiki.debian.org/TeXLive?action=AttachFile&do=get&target=debian-equivs-${TEXLIVE_VERSION}-ex.txt" | grep -v '^Depends:' > /tmp/texlive-equiv
RUN set -ex && cd /tmp && equivs-build texlive-equiv && dpkg -i texlive-local_*.deb
RUN rm -fr /tmp/*

FROM base AS basic
# install TeX Live
RUN set -ex && cd /tmp && curl -L https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/${TEXLIVE_VERSION}/install-tl-unx.tar.gz | tar xzv

COPY <<EOF /tmp/texlive.profile
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
RUN set -ex && cd /tmp && perl install-tl-*/install-tl --scheme basic --repository https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/${TEXLIVE_VERSION}/tlnet-final --profile /tmp/texlive.profile && rm -fr /tmp/*

RUN set -ex && mkdir -p /etc/texmf/texmf.d && perl -p -e "s!\\\$?SELFAUTOLOC!$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*)!g;" \
  -e "s!\\\$?SELFAUTODIR!/usr/local/texlive/${TEXLIVE_VERSION}/bin!g;" \
  -e "s!\\\$?SELFAUTOPARENT!/usr/local/texlive/${TEXLIVE_VERSION}!g;" \
  -e "s!\\\$?SELFAUTOGRANDPARENT!/usr/local/texlive!g;" \
  < /usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/web2c/texmf.cnf >/etc/texmf/texmf.d/10texlive.cnf
RUN set -ex && mkdir -p /etc/texmf/web2c && perl -p -e "s!\\\$?SELFAUTOLOC!$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*)!g;" \
  -e "s!selfautodir:([\\\",{}])!/usr/local/texlive/${TEXLIVE_VERSION}/bin\$1!g;" \
  -e "s!selfautodir:/?!/usr/local/texlive/${TEXLIVE_VERSION}/bin/!g;" \
  -e "s!selfautoparent:([\\\",{}])!/usr/local/texlive/${TEXLIVE_VERSION}\$1!g;" \
  -e "s!selfautoparent:/?!/usr/local/texlive/${TEXLIVE_VERSION}/!g;" \
  < /usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/web2c/texmfcnf.lua >/etc/texmf/web2c/texmfcnf.lua

# LaTeXML (see latexml.sty) and BookML dependencies
RUN /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/tlmgr install comment dvisvgm latexmk preview texfot url

# workaround difficulties in setting PATH in Docker
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

FROM basic AS small
RUN set -ex && PATH="$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH" tlmgr install scheme-small
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

FROM small AS medium
RUN set -ex && PATH="$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH" tlmgr install scheme-medium
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

FROM medium AS full
RUN set -ex && PATH="$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH" tlmgr install scheme-full
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

### LaTeXML base layer
FROM ${TEXLIVE_SCHEME} AS latexml
RUN set -ex && apt-get update -qq && apt-get install -qy curl dvisvgm latexml librsvg2-bin --no-install-recommends

ARG LATEXML_VERSION
RUN curl -L https://launchpad.net/ubuntu/+archive/primary/+files/latexml_${LATEXML_VERSION}-1_all.deb -o /latexml_${LATEXML_VERSION}-1_all.deb
RUN set -ex && dpkg -i /latexml_${LATEXML_VERSION}-1_all.deb || apt -f install && rm /latexml_${LATEXML_VERSION}-1_all.deb
# use dvisvgm from system so as to have matching libgs, mupdf
RUN rm /usr/local/bin/dvisvgm

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
  MAGICK_TIME_LIMIT=900

### BookML
FROM latexml AS bookml

RUN set -ex && apt-get update -qq && apt-get -qy install \
  make \
  unzip \
  zip

COPY release.zip /release.zip

ARG TEXLIVE_SCHEME
ARG LATEXML_VERSION
ARG BOOKML_VERSION
LABEL org.opencontainers.image.source=https://github.com/vlmantova/bookml
LABEL org.opencontainers.image.title="BookML ${BOOKML_VERSION} runner (LaTeXML ${LATEXML_VERSION}, TeX Live ${TEXLIVE_VERSION} ${TEXLIVE_SCHEME})"
LABEL org.opencontainers.image.licenses=GPL-3.0-or-later
LABEL org.opencontainers.image.version=${BOOKML_VERSION}
LABEL org.opencontainers.image.description="Run BookML in the current working directory. Usage: `docker run --rm -i -t -v.:/source ghcr.io/vlmantova/bookml:${BOOKML_VERSION}`"

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
