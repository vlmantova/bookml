LATEXMLPOSTFLAGS=--timestamp=0 --splitnaming=label

include bookml/bookml.mk

TARGETS=$(TARGETS.HTML) $(AUX_DIR)/html/docs/index.plain.html

# custom rules to create plain style
# very, very hacky: this only works because we are not splitting the file
$(AUX_DIR)/xml/docs.plain.xml: docs.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml) docs.pdf $(AUX_DIR)/xml/docs.xml | $(AUX_DIR)/latexmlaux $(AUX_DIR)/xml
	@$(call bml.prog,latexml: $< → $@)
	@$(call bml.cmd,$(LATEXML) --preamble=literal:\RequirePackage[style=plain]{bookml/bookml} \
	  $(LATEXMLFLAGS) $(LATEXMLEXTRAFLAGS) --log="$(AUX_DIR)/latexmlaux/docs.plain.latexml.log" --destination="$@" "$<")

$(AUX_DIR)/html/%/index.plain.html: LATEXMLPOSTFLAGS+=--nosplit
$(AUX_DIR)/html/%/index.plain.html: $$(AUX_DIR)/xml/$$*.plain.preprocessed-xml $$(AUX_DIR)/html/$$*/index.html $$(BOOKML_DEPS_HTML) $$(if $$(filter $$@,$$(BMLGOALS)),,FORCE) | $$(AUX_DIR)/html
	@$(eval _recurse:=$(if $(filter $@,$(BMLGOALS)),,yes))
	+@$(if $(_recurse),$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$@")
	@$(if $(_recurse),,$(call bml.prog,latexmlpost: $*.plain.xml → $(AUX_DIR)/html/$*/index.plain.html))
	@$(if $(_recurse),,$(call bml.cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  $(if $(SPLITAT),--splitat=$(SPLITAT)) --urlstyle=file --pmml --mathtex \
	  $(LATEXMLPOSTFLAGS) $(LATEXMLPOSTEXTRAFLAGS) --sourcedirectory=. $(LATEXMLPOSTAUTOFLAGS) \
	  --dbfile=$(AUX_DIR)/latexmlaux/"$*".plain.LaTeXML.db --log="$(AUX_DIR)/latexmlaux/$*.plain.latexmlpost.log" --destination="$@" "$<"))
