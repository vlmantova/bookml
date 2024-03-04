# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-23  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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
ifeq ($(is.win),true)
  ospath = $(subst /,\,$1)
  CP     = copy
  MKDIR  = mkdir
  RM     = del /f /s /q
  RMDIR  = rd /s /q
  SASS   = sass
  UNZIP	 = tar -C $1 -xf $2
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
GITBOOK_CSS    := $(patsubst %,$(GITBOOK_SOURCE)/css/%,style.css plugin-table.css plugin-bookdown.css plugin-fontsettings.css fontawesome/fontawesome-webfont.ttf)
GITBOOK_JS     := $(patsubst %,$(GITBOOK_SOURCE)/js/%,app.min.js plugin-fontsettings.js plugin-bookdown.js)
GITBOOK_DIRS   := $(patsubst %,gitbook/%,css/fontawesome css js) gitbook
GITBOOK_OUT    := $(patsubst $(GITBOOK_SOURCE)/%,gitbook/%,$(GITBOOK_CSS) $(GITBOOK_JS))

CSS          := $(patsubst %.scss,%.css,$(wildcard CSS/*.scss))
BOOKML_CSS   := $(patsubst %,bookml/%,$(CSS))
BOOKML_XSLT  := $(patsubst %,bookml/%,$(wildcard XSLT/*))
BOOKML_LTX   := bookml/bookml.sty bookml/latexml.sty
BOOKML_LTXML := bookml/bookml.sty.ltxml bookml/schema.rng
BOOKML_MK    := bookml/bookml.mk bookml/xsltproc.pl
BOOKML_DIRS  := $(patsubst %,bookml/%,$(GITBOOK_DIRS)) bookml/CSS bookml/XSLT bookml
BOOKML_OUT   := $(BOOKML_CSS) $(BOOKML_XSLT) $(BOOKML_LTX) $(BOOKML_LTXML) $(BOOKML_MK)

RELEASE_OUT  := $(patsubst %,bookml/%,$(GITBOOK_OUT)) $(BOOKML_OUT) bookml/GNUmakefile

.PHONY: all release clean test
.PRECIOUS:
.SECONDARY:
.SECONDEXPANSION:

all: $(GITBOOK_OUT) $(CSS)

release: release.zip example.zip template.zip

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
	cd $* && set TZ=UTC+00 && zip -r "../release.zip" $(patsubst $*/%,%,$(wildcard $*/*.tex)) GNUmakefile --output-file "../$@"

clean:
	-$(RMDIR) test-example test-template
	-$(RMDIR) $(call ospath,$(RELEASE_OUT) $(GITBOOK_OUT) $(GITBOOK_DIRS) $(BOOKML_OUT) $(BOOKML_DIRS) $(CSS) *.zip)

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

$(patsubst %,bookml/%,bookml.mk bookml.sty bookml.sty.ltxml XSLT/utils.xsl): bookml/%: % | $(BOOKML_DIRS)
	$(eval _date:=$(shell git log HEAD^..HEAD --format='%ad' --date='format:%Y/%m/%d'))
	$(eval _version:=$(shell git log HEAD^..HEAD --format='%(describe)'))
	sed -e "s!@DATE@!$(_date)!g" \
	    -e "s!@VERSION@!$(_version)!g" "$<" > "$@"

# fix erratic positioning of the prev/next buttons due to buggy rounding
gitbook/js/app.min.js: $(GITBOOK_SOURCE)/js/app.min.js | $(GITBOOK_DIRS)
	sed -e "s/parseInt(\([^;]*\)\.css(\"width\"),10)/\1[0].getBoundingClientRect().width/g" "$<" > "$@"

# patch automatic TOC highlighting and scrolling
gitbook/js/plugin-bookdown.js: $(GITBOOK_SOURCE)/js/plugin-bookdown.js plugin-bookdown.js.patch | $(GITBOOK_DIRS)
	$(CP) "$(call ospath,$<)" "$(call ospath,$@)"
	patch -p1 <plugin-bookdown.js.patch

CSS/%.css: CSS/%.scss
	$(SASS) "$<" "$@"
