SPLITAT=
LATEXMLPOSTEXTRAFLAGS=--timestamp=0
include bookml/bookml.mk

# custom rules to create plain style
# very hacky and not recommended until LaTeXML implements f:resource() or similar in XSLT
docs.zip: docs/index.plain.html

docs.plain.xml: docs.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml)
	$(LATEXML) --preamble=literal:\\RequirePackage[style=plain]{bookml/bookml} \
	  --log="$(AUX_DIR)/docs.plain.latexml.log" --destination="$@" "$<"

# ensure that docs/index.html is built first, since it moves away the docs folder
docs/index.plain.html: docs.plain.xml $(BOOKML_DEPS_HTML) $(wildcard bmlimages/docs*.svg) docs/index.html
	$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  --urlstyle=file --dbfile=$(AUX_DIR)/docs.plain.LaTeXML.db --log="$(AUX_DIR)/docs.plain.latexmlpost.log" \
	  --timestamp=0 --destination="$@" "$<"
