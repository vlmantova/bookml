SPLITAT=
LATEXMLPOSTEXTRAFLAGS=--timestamp=0

# default target
docs.tar:

include bookml/bookml.mk

%.tar: $$(AUX_DIR)/html/$$*/index.html $$(filter-out $$(AUX_DIR)/html/$$*/imsmanifest.xml,$$(filter-out $$(AUX_DIR)/html/$$*/LaTeXML.cache,$$(call bml.reclist.file,$$(AUX_DIR)/html/$$*)))
	tar -cvf $@ --directory=$(AUX_DIR)/html/$* --exclude=./imsmanifest.xml --exclude=./LaTeXML.cache .

# custom rules to create plain style
# very hacky and not recommended until LaTeXML implements f:resource() or similar in XSLT
docs.zip: $(AUX_DIR)/html/docs/index.plain.html
docs.tar: $(AUX_DIR)/html/docs/index.plain.html

# build XML files
$(AUX_DIR)/xml/docs.plain.xml: docs.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml) docs.pdf | $(AUX_DIR)/latexmlaux $(AUX_DIR)/xml
	@$(call bml.prog,latexml: $< → $@)
	@$(call bml.cmd,$(LATEXML) $(if $(call bml.grep,{bookml/bookml},$<),,--preamble=literal:\RequirePackage{bookml/bookml} \
	  ) $(LATEXMLFLAGS) $(LATEXMLEXTRAFLAGS) --log="$(AUX_DIR)/latexmlaux/docs.plain.latexml.log" --destination="$@" "$<")

$(AUX_DIR)/html/docs/index.plain.html: $$(AUX_DIR)/xml/docs.plain.xml $$(AUX_DIR)/html/docs/index.html $$(BOOKML_DEPS_HTML) $$(wildcard bmlimages/docs-*.svg) $$(wildcard bmlimages/docs/docs.dpth) bookml/search_index.pl bookml/XSLT/proc-text.xsl $$(if $$(filter $$@,$$(BMLGOALS)),,FORCE) | $$(AUX_DIR)/html
	@$(eval _recurse:=$(if $(filter $@,$(BMLGOALS)),,yes))
	+@$(if $(_recurse),$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$@")
	@$(if $(_recurse),,$(call bml.prog,latexmlpost: docs.plain.xml → docs/index.plain.html))
	@$(if $(_recurse),,$(call bml.cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  $(if $(SPLITAT),--splitat=$(SPLITAT)) --xsltparameter=BMLSEARCH:yes $(LATEXMLPOSTFLAGS) $(LATEXMLPOSTEXTRAFLAGS) \
	  --dbfile=$(AUX_DIR)/latexmlaux/docs.plain.LaTeXML.db --log="$(AUX_DIR)/latexmlaux/docs.plain.latexmlpost.log" --destination="$@" "$<"))
