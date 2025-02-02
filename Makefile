# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-24  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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


GITBOOK_SOURCE := bookdown/inst/resources/gitbook
GITBOOK_CSS    := $(patsubst %,$(GITBOOK_SOURCE)/css/%,style.css plugin-table.css plugin-search.css plugin-bookdown.css plugin-fontsettings.css fontawesome/fontawesome-webfont.ttf)
GITBOOK_JS     := $(patsubst %,$(GITBOOK_SOURCE)/js/%,app.min.js jquery.highlight.js plugin-search.js plugin-fontsettings.js plugin-bookdown.js)
GITBOOK_DIRS   := gitbook $(patsubst %,gitbook/%,css css/fontawesome js)
GITBOOK_OUT    := $(patsubst $(GITBOOK_SOURCE)/%,gitbook/%,$(GITBOOK_CSS) $(GITBOOK_JS))

CSS          := $(patsubst %.scss,%.css,$(wildcard CSS/*.scss))
BOOKML_CSS   := $(patsubst %,bookml/%,$(CSS))
BOOKML_XSLT  := $(patsubst %,bookml/%,$(wildcard XSLT/*))
BOOKML_LTX   := bookml/bookml-init.sty bookml/bookml.sty bookml/latexml.sty
BOOKML_LTXML := bookml/bookml-init.sty.ltxml  bookml/bookml.sty.ltxml bookml/schema.rng
BOOKML_MK    := bookml/bookml.mk bookml/manifest.pl bookml/search_index.pl bookml/xsltproc.pl
BOOKML_DIRS  := bookml bookml/CSS bookml/XSLT $(patsubst %,bookml/%,$(GITBOOK_DIRS))
BOOKML_OUT   := $(BOOKML_CSS) $(BOOKML_XSLT) $(BOOKML_LTX) $(BOOKML_LTXML) $(BOOKML_MK)

RELEASE_OUT  := $(patsubst %,bookml/%,$(GITBOOK_OUT)) $(BOOKML_OUT) bookml/GNUmakefile

BOOKML_VERSION = $(shell git log HEAD^..HEAD --format='%(describe)')
BOOKML_DATE    = $(shell git log HEAD^..HEAD --format='%ad' --date='format:%Y/%m/%d')

ARCHS=amd64 arm64
SCHEMES=basic small medium mediumextra full
.PHONY: all release clean test $(foreach scheme,$(SCHEMES),docker-manifest-$(scheme)) $(foreach arch,$(ARCHS),$(foreach scheme,$(SCHEMES),docker-build-$(scheme)-$(arch) docker-push-$(scheme)-$(arch)))
.PRECIOUS:
.SECONDARY:
.SECONDEXPANSION:

all: $(GITBOOK_OUT) $(CSS)

release: release.zip example.zip template.zip

docker-ctx:
	@$(MKDIR) "$@"

docker-ctx/release.zip: release.zip | docker-ctx
	$(CP) "$<" "$@"

TEXLIVE_VERSION=2021
LATEXML_VERSION=0.8.8
IS_LATEST=yes
REF=ghcr.io/vlmantova/bookml
$(foreach arch,$(ARCHS),$(foreach scheme,$(SCHEMES),docker-build-$(scheme)-$(arch))): docker-build-%: Dockerfile docker-ctx/release.zip
	$(eval ARCH=$(lastword $(subst -, ,$*)))
	$(eval SCHEME=$(firstword $(subst -, ,$*)))
	$(eval TAG=$(BOOKML_VERSION)-$(ARCH))
	docker build --load --build-arg=BUILDKIT_INLINE_CACHE=1 \
		$(foreach scheme,$(SCHEMES),$(foreach tag,latest-$(ARCH) cache-$(TAG),--cache-from=type=registry,ref=$(REF)-$(scheme):$(tag))) \
		--cache-to=type=registry,ref=$(REF)-$(SCHEME):cache-$(TAG),mode=max --platform linux/$(ARCH) \
		--build-arg=TEXLIVE_VERSION=$(TEXLIVE_VERSION) --build-arg=TEXLIVE_SCHEME=$(SCHEME) \
		--build-arg=LATEXML_VERSION=$(LATEXML_VERSION) --build-arg=BOOKML_VERSION=$(BOOKML_VERSION) \
		--tag=$(REF)-$(SCHEME):$(TAG) $(if $(IS_LATEST),--tag=$(REF)-$(SCHEME):latest-$(ARCH)) \
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
		--annotation=index:org.opencontainers.image.title='BookML $(BOOKML_VERSION) runner (LaTeXML $(LATEXML_VERSION), TeX Live $(TEXLIVE_VERSION) $*)' \
		--annotation=index:org.opencontainers.image.licenses=GPL-3.0-or-later \
		--annotation=index:org.opencontainers.image.version=$(BOOKML_VERSION) \
		--annotation=index:org.opencontainers.image.description='Run BookML in the current working directory. Usage: `docker run --rm -i -t -v.:/source $(REF)-$*:$(BOOKML_VERSION)`' \
		$(foreach arch,$(ARCHS),$(REF)-$*:$(BOOKML_VERSION)-$(arch))

docker-manifest:
	docker buildx imagetools create \
		--tag=$(REF):$(BOOKML_VERSION) $(if $(IS_LATEST),--tag=$(REF):latest) \
		--annotation=index:org.opencontainers.image.source=https://github.com/vlmantova/bookml \
		--annotation=index:org.opencontainers.image.title='BookML $(BOOKML_VERSION) runner (LaTeXML $(LATEXML_VERSION), TeX Live $(TEXLIVE_VERSION) $*)' \
		--annotation=index:org.opencontainers.image.licenses=GPL-3.0-or-later \
		--annotation=index:org.opencontainers.image.version=$(BOOKML_VERSION) \
		--annotation=index:org.opencontainers.image.description='Run BookML in the current working directory. Usage: `docker run --rm -i -t -v.:/source $(REF):$(BOOKML_VERSION)`' \
		$(foreach arch,$(ARCHS),$(REF)-full:$(BOOKML_VERSION)-$(arch))

test: example.zip template.zip
	-$(RMDIR) test-example test-template
	-$(MKDIR) test-example test-template
	$(call UNZIP,example.zip,test-example)
	$(call UNZIP,template.zip,test-template)
	$(MAKE) -C test-template
	$(MAKE) -C test-example

release.zip: $(RELEASE_OUT)
	-$(RM) "$(call ospath,$@)"
	set TZ=UTC+00 && zip -r "$@" $^

example.zip template.zip: %.zip: release.zip $$(wildcard %/*.tex) %/GNUmakefile
	-$(RM) "$(call ospath,$@)"
	cd $* && set TZ=UTC+00 && zip -r "../release.zip" $(patsubst $*/%,%,$(wildcard $*/*.tex) $(wildcard $*/.github)) GNUmakefile --output-file "../$@"

clean:
	-$(RMDIR) test-example test-template docker-ctx
	-$(RMDIR) $(call ospath,$(call reverse,$(RELEASE_OUT) $(GITBOOK_OUT) $(GITBOOK_DIRS) $(BOOKML_OUT) $(BOOKML_DIRS) $(CSS) *.zip))

$(GITBOOK_SOURCE):
	git submodule update --init bookdown

$(GITBOOK_CSS) $(GITBOOK_JS): $(GITBOOK_SOURCE)

$(BOOKML_DIRS) $(GITBOOK_DIRS):
	$(MKDIR) "$(call ospath,$@)"

gitbook/%: $(GITBOOK_SOURCE)/% | $(GITBOOK_DIRS)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

bookml/%: % | $(BOOKML_DIRS)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

bookml/GNUmakefile: template/GNUmakefile | $(BOOKML_DIRS)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"

bookml/bookml.sty: bookml.sty | $(BOOKML_DIRS)

$(patsubst %,bookml/%,bookml.mk bookml-init.sty bookml-init.sty.ltxml bookml.sty bookml.sty.ltxml XSLT/utils.xsl): bookml/%: % | $(BOOKML_DIRS)
	perl -pe "s!\@DATE@!$(BOOKML_DATE)!g; s!\@VERSION@!$(BOOKML_VERSION)!g" "$<" > "$@"

# fix erratic positioning of the prev/next buttons due to buggy rounding
gitbook/js/app.min.js: $(GITBOOK_SOURCE)/js/app.min.js | $(GITBOOK_DIRS)
	perl -pe "s/parseInt(\([^;]*\)\.css(\"width\"),10)/\1[0].getBoundingClientRect().width/g" "$<" > "$@"

# patch automatic TOC highlighting and scrolling
gitbook/js/plugin-bookdown.js: $(GITBOOK_SOURCE)/js/plugin-bookdown.js plugin-bookdown.js.patch | $(GITBOOK_DIRS)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"
	patch -p1 <plugin-bookdown.js.patch

# patch search
gitbook/js/plugin-search.js: $(GITBOOK_SOURCE)/js/plugin-search.js plugin-search.js.patch | $(GITBOOK_DIRS)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"
	patch -p1 <plugin-search.js.patch

CSS/%.css: CSS/%.scss
	$(SASS) "$<" "$@"
