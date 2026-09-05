LATEXMLPOSTFLAGS=--timestamp=0 --splitnaming=label --urlstyle=negotiated
SOURCES=docs.tex docs-plain.tex
FORMATS=
TARGETS=$(AUX_DIR)/html/docs/index.html $(AUX_DIR)/html/docs/plain/index.html

docs_plain_LATEXMLPOSTFLAGS = --nosplit

include bookml/bookml.mk

$(AUX_DIR)/html/docs/plain/index.html: $(AUX_DIR)/html/docs-plain/index.html | $(AUX_DIR)/html/docs/index.html
	cp -r '$(<D)' '$(@D)'