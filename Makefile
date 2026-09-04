# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-25  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

is.win  := $(if $(subst xWindows_NT,,x$(OS)),,true)
reverse =  $(if $(1),$(call reverse,$(wordlist 2,$(words $(1)),$(1))) $(firstword $(1)))
ifeq ($(is.win),true)
  ospath = $(subst /,\,$1)
  SHELL  = cmd.exe
  CP     = copy
  MKDIR  = mkdir
  RM     = del /f /s /q
  RMDIR  = rd /s /q
  SASS   = sass
  UNZIP	 = tar -C $2 -xf $1
else
  ospath  = $1
  CP      = cp
  MKDIR   = mkdir -p
  RM      = rm -f --
  RMDIR   = rm -fr --
  SASS    = sass
  UNZIP   = unzip -o $1 -d $2
endif
SASSFLAGS ?= --style=compressed


GITBOOK_SOURCE := bookdown/inst/resources/gitbook
GITBOOK_CSS    := $(patsubst %,$(GITBOOK_SOURCE)/css/%,style.css plugin-table.css plugin-search.css plugin-bookdown.css plugin-fontsettings.css)
GITBOOK_TTF    := $(GITBOOK_SOURCE)/css/fontawesome/fontawesome-webfont.ttf
GITBOOK_JS     := $(patsubst %,$(GITBOOK_SOURCE)/js/%,app.min.js jquery.highlight.js plugin-search.js plugin-fontsettings.js plugin-bookdown.js)
GITBOOK_DIRS   := gitbook $(patsubst %,gitbook/%,css css/fontawesome js)
GITBOOK_OUT    := $(patsubst $(GITBOOK_SOURCE)/%,gitbook/%,$(GITBOOK_CSS) $(GITBOOK_TTF:.ttf=.woff2) $(GITBOOK_JS))

CSS          := $(patsubst %.scss,%.css,$(wildcard CSS/*.scss))
BOOKML_CSS   := $(CSS)
BOOKML_JS    := $(wildcard js/*)
BOOKML_XSLT  := $(wildcard XSLT/*)
BOOKML_LTX   := $(wildcard bookml*.sty) latexml.sty
BOOKML_LTXML := $(wildcard bookml*.ltxml bookml*.rhai) schema.rng $(wildcard bindings/*/*.ltxml bindings/*/*.rhai) bmlimages.pl resources.pl
BOOKML_MK    := $(wildcard bml-*.mk) bookml.mk bookml.pm deps.pl manifest.pl search_index.pl xraux.pl xsltproc.pl
BOOKML_OUT   := $(addprefix bookml/,$(BOOKML_CSS) $(BOOKML_JS) $(BOOKML_XSLT) $(BOOKML_LTX) $(BOOKML_LTXML) $(BOOKML_MK))

RELEASE_OUT  := $(addprefix bookml/,$(GITBOOK_OUT)) $(BOOKML_OUT) bookml/GNUmakefile

TEST_DIRS    := $(patsubst %,test/%,$(BOOKML_DIRS))
TEST_OUT     := $(patsubst %,test/bookml/%,$(GITBOOK_OUT)) $(patsubst %,test/%,$(BOOKML_OUT))

BOOKML_VERSION = $(shell git log HEAD^..HEAD --format='%(describe)')
BOOKML_DATE    = $(shell git log HEAD^..HEAD --format='%ad' --date='format:%Y/%m/%d')

ARCHS=amd64 arm64
SCHEMES=basic small medium mediumextra full
.PHONY: all release clean test $(foreach scheme,$(SCHEMES),docker-manifest-$(scheme)) $(foreach arch,$(ARCHS),$(foreach scheme,$(SCHEMES),docker-build-$(scheme)-$(arch) docker-push-$(scheme)-$(arch)))
.PRECIOUS:
.SECONDARY:
.SECONDEXPANSION:

.PHONY: all bookml release test clean

all: $(GITBOOK_OUT) $(CSS)

bookml: $(RELEASE_OUT)

release: release.zip example.zip template.zip

docker-ctx/release.zip: release.zip | docker-ctx/./
	$(CP) "$<" "$@"

TEXLIVE_VERSION=2021
LATEXML_VERSION=0.8.8
LATEXMLOXIDE_VERSION=0.7.6
IS_LATEST=yes
REF=ghcr.io/vlmantova/bookml
$(foreach arch,$(ARCHS),$(foreach scheme,$(SCHEMES),docker-build-$(scheme)-$(arch))): docker-build-%: Dockerfile docker-ctx/release.zip
	$(eval ARCH=$(lastword $(subst -, ,$*)))
	$(eval SCHEME=$(firstword $(subst -, ,$*)))
	$(eval TAG=$(BOOKML_VERSION)-$(ARCH))
	docker buildx build --load --build-arg=BUILDKIT_INLINE_CACHE=1 \
		$(foreach scheme,$(SCHEMES),$(foreach tag,latest-$(ARCH) cache-$(TAG),--cache-from=type=registry,ref=$(REF)-$(scheme):$(tag))) \
		--cache-to=type=registry,ref=$(REF)-$(SCHEME):cache-$(TAG),mode=max,compression=zstd,oci-mediatypes=true --platform linux/$(ARCH) \
		--build-arg=TEXLIVE_VERSION=$(TEXLIVE_VERSION) --build-arg=TEXLIVE_SCHEME=$(SCHEME) \
		--build-arg=LATEXML_VERSION=$(LATEXML_VERSION) --build-arg=BOOKML_VERSION=$(BOOKML_VERSION) \
		--build-arg=LATEXMLOXIDE_VERSION=$(LATEXMLOXIDE_VERSION) \
		--tag=$(REF)-$(SCHEME):$(TAG) $(if $(IS_LATEST),--tag=$(REF)-$(SCHEME):latest-$(ARCH)) \
		--output type=docker,compression=zstd,oci-mediatypes=true \
		-f "$<" docker-ctx

$(foreach arch,$(ARCHS),$(foreach scheme,$(SCHEMES),docker-push-$(scheme)-$(arch))): docker-push-%: docker-build-%
	$(eval ARCH=$(lastword $(subst -, ,$*)))
	$(eval SCHEME=$(firstword $(subst -, ,$*)))
	$(eval TAG=$(BOOKML_VERSION)-$(ARCH))
	docker push $(REF)-$(SCHEME):$(TAG)
	$(if $(IS_LATEST),docker push $(REF)-$(SCHEME):latest-$(ARCH))

$(foreach scheme,$(SCHEMES),docker-manifest-$(scheme)): docker-manifest-%:
	docker buildx imagetools create \
		--tag=$(REF)-$*:$(BOOKML_VERSION) $(if $(IS_LATEST),--tag=$(REF)-$*:latest) \
		--annotation=index:org.opencontainers.image.source=https://github.com/vlmantova/bookml \
		--annotation=index:org.opencontainers.image.title='BookML $(BOOKML_VERSION) runner (LaTeXML $(LATEXML_VERSION), latexml-oxide $(LATEXMLOXIDE_VERSION), TeX Live $(TEXLIVE_VERSION) $*)' \
		--annotation=index:org.opencontainers.image.licenses=GPL-3.0-or-later \
		--annotation=index:org.opencontainers.image.version=$(BOOKML_VERSION) \
		--annotation=index:org.opencontainers.image.description='Run BookML in the current working directory. Usage: `docker run --rm -i -t -v.:/source $(REF)-$*:$(BOOKML_VERSION)`' \
		$(foreach arch,$(ARCHS),$(REF)-$*:$(BOOKML_VERSION)-$(arch))

docker-manifest:
	docker buildx imagetools create \
		--tag=$(REF):$(BOOKML_VERSION) $(if $(IS_LATEST),--tag=$(REF):latest) \
		--annotation=index:org.opencontainers.image.source=https://github.com/vlmantova/bookml \
		--annotation=index:org.opencontainers.image.title='BookML $(BOOKML_VERSION) runner (LaTeXML $(LATEXML_VERSION), latexml-oxide $(LATEXMLOXIDE_VERSION), TeX Live $(TEXLIVE_VERSION) $*)' \
		--annotation=index:org.opencontainers.image.licenses=GPL-3.0-or-later \
		--annotation=index:org.opencontainers.image.version=$(BOOKML_VERSION) \
		--annotation=index:org.opencontainers.image.description='Run BookML in the current working directory. Usage: `docker run --rm -i -t -v.:/source $(REF):$(BOOKML_VERSION)`' \
		$(foreach arch,$(ARCHS),$(REF)-full:$(BOOKML_VERSION)-$(arch))

test: $(TEST_OUT)
	$(MAKE) -C test $(TESTFLAGS)

release.zip: $(RELEASE_OUT)
	-$(RM) "$(call ospath,$@)"
	set TZ=UTC+00 && zip -r "$@" $^

example.zip template.zip: %.zip: release.zip $$(wildcard %/*.tex) %/GNUmakefile
	-$(RM) "$(call ospath,$@)"
	cd $* && set TZ=UTC+00 && zip -r "../release.zip" $(patsubst $*/%,%,$(wildcard $*/*.tex) $(wildcard $*/RENAME_ME_TO.github)) GNUmakefile --output-file "../$@"

clean:
	-$(RMDIR) test-example test-template
	-$(RMDIR) docker-ctx/release.zip $(call ospath,$(call reverse,$(RELEASE_OUT) $(GITBOOK_OUT) $(GITBOOK_DIRS) $(BOOKML_OUT) $(BOOKML_DIRS) $(TEST_OUT) $(TEST_DIRS) $(CSS) *.zip))

$(GITBOOK_SOURCE):
	git submodule update --init bookdown

$(GITBOOK_CSS) $(GITBOOK_TTF) $(GITBOOK_JS): $(GITBOOK_SOURCE)

bookml/./:
	$(MKDIR) "$(call ospath,$@)"

bookml/%/./:
	$(MKDIR) "$(call ospath,$@)"

gitbook/%/./:
	$(MKDIR) "$(call ospath,$@)"

test/bookml/./:
	$(MKDIR) "$(call ospath,$@)"

test/bookml/%/./:
	$(MKDIR) "$(call ospath,$@)"

gitbook/%: $(GITBOOK_SOURCE)/% | $$(@D)/./
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

bookml/%: % | $$(@D)/./
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

test/bookml/%: bookml/% | $$(if $$(filter %/./,$$@),,$$(@D)/./)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

bookml/GNUmakefile: template/GNUmakefile | $$(@D)/./
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

$(patsubst %,bookml/%,bml-detect.mk $(wildcard *.ltxml *.rhai *.sty) XSLT/utils.xsl): bookml/%: % | $$(@D)/./
	perl -pe "s!\@DATE@!$(BOOKML_DATE)!g; s!\@VERSION@!$(BOOKML_VERSION)!g" "$<" > "$@"

# fix erratic positioning of the prev/next buttons due to buggy rounding
gitbook/js/app.min.js: $(GITBOOK_SOURCE)/js/app.min.js app.min.js.pl | $$(@D)/./
	perl -p app.min.js.pl "$<" > "$@"

# bookdown javascript patches
gitbook/js/%.js: $(GITBOOK_SOURCE)/js/%.js %.js.patch | $$(@D)/./
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"
	patch -p1 <$*.js.patch

# subset font awesome
# fa-check, fa-font, fa-search, fa-edit, fa-history, fa-eye, fa-file-pdf-o, fa-download, fa-info, fa-clone, fa-angle-left, fa-angle-right, fa-align-justify
# f00c, f031, f002, f044, f1da, f06e, f1c1, f019, f129, f24d, f104, f105, f039
gitbook/%.woff2: $(GITBOOK_SOURCE)/%.ttf | $$(@D)/./
	pyftsubset "$<" --output-file="$@" --unicodes="f00c,f031,f002,f044,f1da,f06e,f1c1,f019,f129,f24d,f104,f105,f039" --flavor=woff2

gitbook/css/style.css: $(GITBOOK_SOURCE)/css/style.css | $$(@D)/./
	perl -p -e "s!\('\./fontawesome/fontawesome-webfont.ttf\?v=4\.7\.0'\) format\('truetype'\)!('\./fontawesome/fontawesome-webfont.woff2') format('woff2')!" "$<" > "$@"

CSS/%.css: CSS/%.scss
	$(SASS) $(SASSFLAGS) "$<" "$@"
