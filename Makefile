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

GITBOOK_CSS = style.css plugin-table.css plugin-bookdown.css plugin-fontsettings.css fontawesome/fontawesome-webfont.ttf
GITBOOK_JS  = app.min.js plugin-fontsettings.js plugin-bookdown.js
GITBOOK_OUT = $(patsubst %,bookml/gitbook/%,$(GITBOOK_CSS) $(GITBOOK_JS))

BOOKML_CSS  = $(patsubst %,bookml/%,$(wildcard CSS/*))
BOOKML_XSLT = $(patsubst %,bookml/%,$(wildcard XSLT/*))

# up to date animate, media9, pdfbase for producing compliant SVGs
TEX_DEPS     = bookml/bookml.sty animate.sty media9.sty pdfbase.sty
XML_DEPS     = bookml/bookml.sty.ltxml
GITBOOK_DEPS = $(wildcard bmluser/*.*gitbook*.css) $(wildcard bmluser/*.*_all*.css)
PLAIN_DEPS   = $(wildcard bmluser/*.*plain*.css) $(wildcard bmluser/*.*_all*.css)
POST_DEPS    = $(BOOKML_CSS) $(BOOKML_XSLT) $(GITBOOK_OUT)

SPLIT = $(patsubst %,--splitat=%,$(SPLITAT))

.PHONY: all clean
.PRECIOUS:
.SECONDARY:

all: docs/index.html docs/index.plain.html

clean:
	-latexmk -C docs.tex
	-rm -f -r docs.*.log docs*.xml docs.epub bmlimages docs

bookml/gitbook:
	make -C bookml

bookml/bookml.sty:
	git submodule update --init bookml

$(BOOKML_CSS) $(BOOKML_XSLT) $(XML_DEPS): bookml/bookml.sty

$(GITBOOK_OUT): bookml/gitbook | bookml/bookml.sty

%.pdf: %.tex $(TEX_DEPS)
	latexmk -pdf -interaction=nonstopmode -halt-on-error "$<"

%.bib.xml: %.bib
	$(LML_PREFIX)latexml --preload=amssymb --dest="$@" "$<"

%.xml: %.tex $(XML_DEPS) $(TEX_DEPS) $(GITBOOK_DEPS) | %.pdf %.epub
	$(LML_PREFIX)latexml --dest="$@" "$<"

%.plain.xml: %.tex $(XML_DEPS) $(TEX_DEPS) $(PLAIN_DEPS) | %.pdf
	$(LML_PREFIX)latexml --preload=[style=plain]bookml/bookml --dest="$@" "$<"

%.epub: %.tex $(XML_DEPS) $(EPUB_DEPS) $(PLAIN_DEPS)
	$(LML_PREFIX)latexmlc --preload=[style=plain]bookml/bookml --dest="$@" --splitat=section "$<"

%/index.html: %.xml $(POST_DEPS) $(GITBOOK_DEPS) #%.pdf %.epub
	$(LML_PREFIX)latexmlpost --navigationtoc=context --dest="$@" --timestamp=0 $(SPLIT) "$<"

%/index.plain.html: %.plain.xml $(POST_DEPS) $(PLAIN_DEPS) %.pdf
	$(LML_PREFIX)latexmlpost --dest="$@" --timestamp=0 $(SPLIT) "$<"
