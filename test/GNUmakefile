MATHSTESTS=amsldoc-equations disable-mathjax latexml-t-ams-mathtools mathtools mathvariants
CODETESTS=algorithm2e algorithmic algorithmicx
SOURCES=tests.tex algorithm2e.tex algorithmic.tex algorithmicx.tex images.tex inline-html.tex listings.tex $(foreach opt,mathjax2 mathjax3 mathjax4 nomathjax,$(MATHSTESTS:=-$(opt).tex))
TARGETS=$(TARGETS.HTML)
SPLITAT=

images_LATEXML=latexml_oxide

html:
-include bookml/bookml.mk

.PHONY: $(MATHSTESTS) algorithmicx code equations images inline-html listings

equations: amsldoc-equations latexml-t-ams-mathtools mathtools
code: algorithmic algorithmicx listings

algorithm2e algorithmic algorithmicx images inline-html listings: %: $(AUX_DIR)/html/%/index.html

define test
$(eval
$1: $(MATHSTESTS:=-$1.tex)

$(MATHSTESTS): %: $(AUX_DIR)/html/%-$1/index.html

%-$1.tex: test-template.tex.in
	perl -pe "s!\@OPTIONS\@!$2!; s!\@INPUT\@!$$*.tex!g" "$$<" > "$$@"
)
endef

$(call test,nomathjax,nomathjax)
$(call test,mathjax2,mathjax=2)
$(call test,mathjax3,mathjax=3)
$(call test,mathjax4,mathjax=4)
