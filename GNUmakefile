SPLITAT=
LATEXMLPOSTEXTRAFLAGS=--timestamp=0
include bookml/bookml.mk

# custom rules to create plain style
# very hacky and not recommended until LaTeXML implements f:resource() or similar in XSLT
docs.zip: $(AUX_DIR)/html/docs/index.plain.html

$(AUX_DIR)/xml/docs.plain.xml: docs.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml)
	$(LATEXML) --preamble=literal:\\RequirePackage[style=plain]{bookml/bookml} \
	  --log="$(AUX_DIR)/latexmlaux/docs.plain.latexml.log" --destination="$@" "$<"

$(AUX_DIR)/html/docs/index.plain.html: $(AUX_DIR)/xml/docs.plain.xml $(BOOKML_DEPS_HTML) $(wildcard bmlimages/docs*.svg)
	$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  --urlstyle=file --dbfile=$(AUX_DIR)/latexmlaux/docs.plain.LaTeXML.db --log="$(AUX_DIR)/latexmlaux/docs.plain.latexmlpost.log" \
	  --timestamp=0 --destination="$@" "$<"
