# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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

VERSION  := $(shell git describe --dirty)
RELEASE  := bookml-$(VERSION).zip
EXAMPLE  := example-$(VERSION).zip

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
BOOKML_MK    := bookml/bookml.mk
BOOKML_DIRS  := $(patsubst %,bookml/%,$(GITBOOK_DIRS)) bookml/CSS bookml/XSLT bookml
BOOKML_OUT   := $(BOOKML_CSS) $(BOOKML_XSLT) $(BOOKML_LTX) $(BOOKML_LTXML) $(BOOKML_MK)

RELEASE_OUT  := $(patsubst %,bookml/%,$(GITBOOK_OUT)) $(BOOKML_OUT)

.PHONY: all release clean
.PRECIOUS:
.SECONDARY:

all: $(GITBOOK_OUT) $(CSS)

release: $(RELEASE) $(EXAMPLE)

$(RELEASE): $(RELEASE_OUT)
	-rm -f "$@"
	TZ=UTC+00 zip -r "$@" $^

$(EXAMPLE): $(RELEASE) example/main.tex example/secondfile.tex example/chapter1.tex example/Makefile
	-rm -f "$@"
	cd example ; TZ=UTC+00 zip -r "../$<" main.tex secondfile.tex chapter1.tex Makefile --output-file "../$@"

clean:
	-rm -f -d $(RELEASE_OUT) $(GITBOOK_OUT) $(GITBOOK_DIRS) $(BOOKML_OUT) $(BOOKML_DIRS) $(CSS) *.zip

$(GITBOOK_SOURCE):
	git submodule update --init bookdown

$(GITBOOK_CSS) $(GITBOOK_JS): $(GITBOOK_SOURCE)

$(BOOKML_DIRS) $(GITBOOK_DIRS):
	mkdir --parents "$@"

gitbook/%: $(GITBOOK_SOURCE)/% | $(GITBOOK_DIRS)
	cp "$<" "$@"

bookml/%: % | $(BOOKML_DIRS)
	cp "$<" "$@"

# fix erratic positioning of the prev/next buttons due to buggy rounding
gitbook/js/app.min.js: $(GITBOOK_SOURCE)/js/app.min.js | $(GITBOOK_DIRS)
	sed -e 's/parseInt(\([^;]*\)\.css("width"),10)/\1[0].getBoundingClientRect().width/g' "$<" > "$@"

# patch automatic TOC highlighting and scrolling
gitbook/js/plugin-bookdown.js: $(GITBOOK_SOURCE)/js/plugin-bookdown.js plugin-bookdown.js.patch | $(GITBOOK_DIRS)
	cp "$<" "$@"
	patch -p1 <plugin-bookdown.js.patch

CSS/%.css: CSS/%.scss
	sassc "$<" "$@"
