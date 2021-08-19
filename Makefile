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

VERSION = $(shell git describe)
RELEASE = bookml-$(VERSION).zip

BOOKDOWN_SOURCE = bookdown-source/inst/resources
GITBOOK = $(foreach wd,css/*.css css/fontawesome/*.ttf js/*.js,$(wildcard $(BOOKDOWN_SOURCE)/gitbook/$(wd)))
JQUERY = $(wildcard $(BOOKDOWN_SOURCE)/jquery/*.js)
BOOKDOWN_OUT_DIRS = $(patsubst %,bookml/%,gitbook/css/fontawesome gitbook/css gitbook/js gitbook jquery)
BOOKDOWN_OUT = $(patsubst $(BOOKDOWN_SOURCE)/%,bookml/%,$(GITBOOK) $(JQUERY))

TEX_DEPS = bookml.sty bookml/bookml-latex.sty
XML_DEPS = bookml.sty.ltxml bookml/bookml-perl.pl
HTML_DEPS = LaTeXML-html5.xsl $(wildcard bookml/*.xsl) $(wildcard bookml/*.css) $(BOOKDOWN_OUT)

.PHONY: all clean release
.PRECIOUS: docs.dvi docs.ps docs.pdf

all: $(BOOKDOWN_OUT) docs/index.html docs/index.nogitbook.html

clean:
	-latexmk -C docs.tex
	-rm -f -r docs.*.log docs*.xml bmlimages docs
	-rm -f -d $(BOOKDOWN_OUT) $(BOOKDOWN_OUT_DIRS) $(RELEASE)

release: $(RELEASE)

$(RELEASE): $(TEX_DEPS) $(XML_DEPS) $(HTML_DEPS)
	-rm -f "$@"
	TZ=UTC+00 zip -r "$@" $^

$(BOOKDOWN_OUT_DIRS):
	mkdir --parents "$@"

bookml/%: $(BOOKDOWN_SOURCE)/% | $(BOOKDOWN_OUT_DIRS)
	cp "$<" "$@"

# fix erratic positioning of the prev/next buttons due to buggy rounding
bookml/gitbook/js/app.min.js: $(BOOKDOWN_SOURCE)/gitbook/js/app.min.js | $(BOOKDOWN_OUT_DIRS)
	sed -e 's/parseInt(\([^;]*\)\.css("width"),10)/\1[0].getBoundingClientRect().width/g' "$<" > "$@"

# patch automatic TOC highlighting and scrolling
bookml/gitbook/js/plugin-bookdown.js: $(BOOKDOWN_SOURCE)/gitbook/js/plugin-bookdown.js bookml/plugin-bookdown.js.patch | $(BOOKDOWN_OUT_DIRS)
	cp "$<" "$@"
	patch -p1 <bookml/plugin-bookdown.js.patch

%.pdf: %.tex $(TEX_DEPS)
	latexmk -pdf -interaction=nonstopmode -halt-on-error "$<"

%.bib.xml: %.bib
	latexml --preload=amssymb --dest="$@" "$<"

%.xml: %.tex $(XML_DEPS)
	latexml --dest="$@" "$<"

%.nogitbook.xml: %.tex $(XML_DEPS)
	latexml --preload=[nogitbook]bookml --dest="$@" "$<"

%/index.html: %.xml $(HTML_DEPS)
	latexmlpost --navigationtoc=context --dest="$@" --timestamp=0 "$<"

docs/index.html: docs.xml $(HTML_DEPS) docs.pdf
	latexmlpost --navigationtoc=context --dest="$@" --timestamp=0 "$<"

docs/index.nogitbook.html: docs.nogitbook.xml $(HTML_DEPS) docs.pdf
	latexmlpost --dest="$@" --timestamp=0 "$<"
