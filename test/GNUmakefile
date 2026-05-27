TESTS=amsldoc-equations disable-mathjax latexml-t-ams-mathtools mathtools mathvariants
SOURCES=tests.tex $(foreach opt,mathjax2 mathjax3 mathjax4 nomathjax,$(TESTS:=-$(opt).tex))
TARGETS=$(TARGETS.HTML)
SPLITAT=

html:
-include bookml/bookml.mk

.PHONY: $(TESTS) equations

equations: amsldoc-equations latexml-t-ams-mathtools mathtools

define test
$(eval
$1: $(TESTS:=-$1.tex)

$(TESTS): %: $(AUX_DIR)/html/%-$1/index.html

%-$1.tex: test-template.tex.in
	perl -pe "s/\@OPTIONS\@/$2/; s/\@INPUT\@/$$*.tex/g" "$$<" > "$$@"
)
endef

$(call test,nomathjax,nomathjax)
$(call test,mathjax2,mathjax=2)
$(call test,mathjax3,mathjax=3)
$(call test,mathjax4,mathjax=4)
