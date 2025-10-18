### TeX Live base layers
ARG TEXLIVE_SCHEME=small
ARG LATEXML_VERSION=0.8.8
# freeze Ubuntu version to minimize rebuilds
FROM ubuntu:24.04@sha256:b359f1067efa76f37863778f7b6d0e8d911e3ee8efa807ad01fbf5dc1ef9006b AS base

ARG DEBIAN_FRONTEND=noninteractive
# TL 2021 is the latest version for which expl3 loads in reasonable time
ARG TEXLIVE_VERSION=2021
# dependencies copied from Docker TeX Live images + LaTeXML and BookML dependencies
# TODO move dependencies to schemes that need them
RUN <<EOF
  set -eux
  apt update -qq
  apt install -qy tzdata curl perl-modules
  apt install -qy gpg ghostscript libgetopt-long-descriptive-perl libdigest-perl-md5-perl libncurses6 libunicode-linebreak-perl libfile-homedir-perl libyaml-tiny-perl ghostscript libsm6 python3 python3-pygments gnuplot-nox libglut3.12 dvisvgm imagemagick librsvg2-bin mupdf-tools make unzip zip --no-install-recommends
EOF
# install texlive-local equiv pacakge
RUN <<EOF
  set -eux
  cd /tmp
  curl -L "https://wiki.debian.org/TeXLive?action=AttachFile&do=get&target=debian-equivs-${TEXLIVE_VERSION}-ex.txt" | grep -v '^Depends:' > texlive-equiv
  apt update -qq
  apt install -qy equivs
  equivs-build texlive-equiv
  dpkg -i texlive-local_*.deb
  rm -fr /tmp/*
  apt install -qy latexml tex-common
  apt --purge autoremove -qy equivs
EOF

# fake time so that expired TeX Live signing keys appear as valid
COPY --chmod=755 <<EOF /usr/local/bin/gpg
#!/bin/sh
exec /usr/bin/gpg --faked-system-time ${TEXLIVE_VERSION}1231T235959 "\$@"
EOF

FROM base AS basic
# install TeX Live
COPY <<EOF /tmp/texlive.profile
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
RUN <<EOF
  set -eux
  cd /tmp
  curl -L https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/${TEXLIVE_VERSION}/install-tl-unx.tar.gz | tar xzv
  perl install-tl-*/install-tl --verify-downloads --scheme basic --repository https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/${TEXLIVE_VERSION}/tlnet-final --profile /tmp/texlive.profile
  rm -fr /tmp/*
  mkdir -p /etc/texmf/texmf.d /etc/texmf/web2c
  perl -p -e "s!\\\$?SELFAUTOLOC!$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*)!g;" \
    -e "s!\\\$?SELFAUTODIR!/usr/local/texlive/${TEXLIVE_VERSION}/bin!g;" \
    -e "s!\\\$?SELFAUTOPARENT!/usr/local/texlive/${TEXLIVE_VERSION}!g;" \
    -e "s!\\\$?SELFAUTOGRANDPARENT!/usr/local/texlive!g;" \
    < /usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/web2c/texmf.cnf >/etc/texmf/texmf.d/10texlive.cnf
  perl -p -e "s!\\\$?SELFAUTOLOC!$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*)!g;" \
    -e "s!selfautodir:([\\\",{}])!/usr/local/texlive/${TEXLIVE_VERSION}/bin\$1!g;" \
    -e "s!selfautodir:/?!/usr/local/texlive/${TEXLIVE_VERSION}/bin/!g;" \
    -e "s!selfautoparent:([\\\",{}])!/usr/local/texlive/${TEXLIVE_VERSION}\$1!g;" \
    -e "s!selfautoparent:/?!/usr/local/texlive/${TEXLIVE_VERSION}/!g;" \
    < /usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/web2c/texmfcnf.lua >/etc/texmf/web2c/texmfcnf.lua
  dpkg-reconfigure tex-common
EOF

# LaTeXML (see latexml.sty) and BookML dependencies
RUN /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/tlmgr install comment dvisvgm latexmk preview texfot url

# workaround difficulties in setting PATH in Docker
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

FROM basic AS small
RUN set -eux && PATH="$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH" tlmgr install scheme-small
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

FROM small AS medium
RUN set -eux && PATH="$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH" tlmgr install scheme-medium
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

# opinionated intermediate scheme that builds in under 6 hours
FROM medium AS mediumextra
RUN set -eux && PATH=$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH tlmgr install collection-bibtexextra collection-fontsextra collection-formatsextra collection-games collection-humanities collection-langarabic collection-langchinese collection-langcjk collection-langcyrillic collection-langgreek collection-langjapanese collection-langkorean collection-langother collection-music collection-pictures collection-pstricks collection-publishers
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

FROM mediumextra AS full
RUN set -eux && PATH="$(readlink -f /usr/local/texlive/${TEXLIVE_VERSION}/bin/*):$PATH" tlmgr install scheme-full
RUN ln -sf -t /usr/local/bin /usr/local/texlive/${TEXLIVE_VERSION}/bin/*/*

### LaTeXML base layer
FROM ${TEXLIVE_SCHEME} AS latexml
# use dvisvgm from system so as to have matching libgs, mupdf
RUN rm /usr/local/bin/dvisvgm

ARG LATEXML_VERSION
RUN <<EOF
  set -eux
  curl -L https://launchpad.net/ubuntu/+archive/primary/+files/latexml_${LATEXML_VERSION}-1_all.deb -o /latexml_${LATEXML_VERSION}-1_all.deb
  dpkg -i /latexml_${LATEXML_VERSION}-1_all.deb
  rm /latexml_${LATEXML_VERSION}-1_all.deb
EOF

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

# patch LaTeXML to report full paths and columns starting from 1
RUN apt install -qy patch
RUN --mount=target=/docker-ctx cat /docker-ctx/latexml-*.patch | patch -d /usr/share/perl5 -p2

### BookML
FROM latexml AS bookml

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
  echo "Replacing BookML with version $BOOKML_VERSION."
  unzip /release.zip
  exit 0
elif [[ -d bookml ]] ; then
  make -q BOOKML_VERSION="$BOOKML_VERSION" -f bookml/bookml.mk check-for-update || echo "BookML update $BOOKML_VERSION available, run "'`update` to install it.'
else
  echo "Unpacking BookML $BOOKML_VERSION."
  unzip -q /release.zip
fi
[[ -f GNUmakefile || -f Makefile ]] || cp bookml/GNUmakefile GNUmakefile
exec make "\$@" BOOKML_VERSION="$BOOKML_VERSION"
EOF

WORKDIR /source
ENTRYPOINT ["/run-bookml"]
