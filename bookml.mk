# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-23 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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

### CONFIGURATION
# Configure these variables inside 'Makefile' before 'include bookml/bookml.mk'
# (1) where to store auxiliary files (*.aux, *.d, *.toc,...)
AUX_DIR  ?= auxdir
DEPS_DIR ?= $(AUX_DIR)/deps
# (2) latexmk command and options
LATEXMK      ?= latexmk
LATEKMKFLAGS ?= -synctex=5
# (3) latexml commands and options
LATEXML          ?= latexml
LATEXMLPOST      ?= latexmlpost
LATEXMLFLAGS     ?=
LATEXMLPOSTFLAGS ?= --urlstyle=file --pmml --mathtex --navigationtoc=context
# (4) for *adding* options without changing the default ones
LATEXMLEXTRAFLAGS     ?=
LATEXMLPOSTEXTRAFLAGS ?=
# (5) perl command
PERL ?= perl
# (6) how to split into multiple files (section, chapter, etc), set to empty string to disable splitting
SPLITAT ?= section
# (7) source files: by default, all .tex files containing a \documentclass
SOURCES ?= $(foreach f,$(wildcard *.tex),$(if $(call bml.grep,\documentclass,$(f)),$(f)))
# (8) files to be built: by default, a .zip and a SCORM.zip file for each .tex file in $(SOURCES)
TARGETS.PDF   ?= $(SOURCES:.tex=.pdf)
TARGETS.XML   ?= $(TARGETS.PDF:.pdf=.xml)
TARGETS.HTML  ?= $(patsubst %.xml,%/index.html,$(TARGETS.XML))
TARGETS.ZIP   ?= $(TARGETS.HTML:/index.html=.zip)
TARGETS.SCORM ?= $(patsubst %/index.html,SCORM.%.zip,$(TARGETS.HTML))
# (9) texfot (optional, disable with TEXFOT=)
TEXFOT      ?= $(if $(call bml.which,texfot),texfot)
TEXFOTFLAGS ?= $(if $(TEXFOT),--no-stderr,)
# (10) various terminal commands: by default, use typical Windows or Unix version
ZIP         ?= $(if $(bml.is.win),$(if $(shell where zip 2>NUL),zip,miktex-zip),zip)
ZIP_EXCLUDE ?= -x
bml.is.win  := $(if $(subst xWindows_NT,,x$(OS)),,true)
CP          := $(if $(bml.is.win),copy,cp)
RMDIR       := $(if $(bml.is.win),rd /s /q,rm -fr --)
RM          := $(if $(bml.is.win),del /f /s /q,rm -f --)
MKDIR       := $(if $(bml.is.win),mkdir,mkdir -p --)
bml.pathsep := $(if $(bml.is.win),$(strip \),/)
bml.null    := $(if $(bml.is.win),2>NUL,2>/dev/null)
### END CONFIGURATION

### INTERNAL VARIABLES
BOOKML_DEPS_HTML = $(wildcard LaTeXML-html5.xsl bookml/XSLT/*.xsl \
  bookml/*.rng bookml/CSS/*.css bookml/gitbook/css/fontawesome/*.ttf \
  bookml/gitbook/css/*.css bookml/js/*.js bmluser/*.css)
BOOKML_DEPS_XML  = $(wildcard bookml/*.ltxml bookml/*.rng)

### UTILS
# find if a command is available
bml.which = $(if $(bml.is.win),$(shell where "$1" 2>NUL),$(shell command -v "$1"))
# recursive wildcard (like https://stackoverflow.com/a/18258352, second version returns files only)
bml.rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call bml.rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
bml.rwildcard.file = $(foreach d,$(wildcard $(1:=/*)),$(eval _x := $(call bml.rwildcard.file,$d,$2))$(if $(_x),$(_x),$(filter $(subst *,%,$2),$d)))
# backward compatible file/grep function
ifeq ($(findstring version-3.8,version-$(MAKE_VERSION)),version-3.8)
  ifeq ($(bml.is.win),true)
    bml.file = $(shell type $(1))
  else
    bml.file = $(shell cat -- $(1))
  endif
else
  bml.file = $(file < $(1))
endif
bml.grep = $(findstring $(1),$(call bml.file,$(2)))

SOURCES := $(SOURCES)

# help editors detect UTF-8 encoding: ∀x.x=x

# bml.prog output (after GMSL)
bml.spc := $(strip) $(strip)
bml.alph  := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
         a b c d e f g h i j k l m n o p q r s t u v w x y z \
         0 1 2 3 4 5 6 7 8 9 ` ~ ! @ \# $$ % ^ & * ( ) - _ = \
         + { } [ ] \ : ; ' " < > , . / ? | →
bml.boxgen = $1$(strip $(eval _t := $(strip $(filter-out $(bml.esc)[%m,$2))) \
  $(foreach a,$(bml.alph),$(eval _t := $$(subst $$a,$1,$(_t)))) \
  $(subst $(bml.spc),,$(foreach a,$(_t),$a$1)))
bml.boxtop =              ▄$(call                                                           bml.boxgen,▄,$1)▄
bml.boxscp = $(bml.bluebg)▌$(subst ­, ,$(call                                                bml.boxgen,­,$1))▐
bml.boxmid = $(bml.bluebg)▌ $(strip $(subst $(bml.spc)$(bml.esc)[,$(bml.esc)[,$1))$(bml.reset)$(bml.bluebg) ▐
bml.boxbot =              ▀$(call                                                           bml.boxgen,▀,$1)▀

bml.cmd  = $(call bml.echo,$(bml.yellow)$(if $(bml.is.win),$1,$(subst ",\",$1))) $(bml;)$1
bml.box  = $(call bml.echo,$(call bml.boxtop,$1)) $(bml;) $(call bml.echo,$(call bml.boxscp,$1)) $(bml;) \
  $(call bml.echo,$(call bml.boxmid,$1)) $(bml;) $(call bml.echo,$(call bml.boxscp,$1)) $(bml;) $(call bml.echo,$(call bml.boxbot,$1))
bml.prog = $(call bml.box,[$(words $(will.zip) $(will.pdf) $(will.html) $(will.xml) $(will.scormmanifest) $(will.scorm))] $1)

# colors
ifeq ($(if $(bml.is.win),true,$(shell tput setaf 1 >/dev/null 2>&1 && echo true)),true)
  bml.esc     := 
  bml.cyan    := $(bml.esc)[96m
  bml.magenta := $(bml.esc)[95m
  bml.yellow  := $(bml.esc)[93m
  bml.green   := $(bml.esc)[92m
  bml.red     := $(bml.esc)[91m
  bml.blue    := $(bml.esc)[34m
  bml.bluebg  := $(bml.esc)[44m
  bml.reset   := $(bml.esc)[0m
endif

ifeq ($(bml.is.win),true)
  SHELL      := cmd.exe
  __ignore   := $(shell chcp 65001)
  bml.echo    = echo $1$(bml.reset) >&2
  bml.ospath  = $(subst /,$(bml.pathsep),$1)
  bml.lt     := ^<
  bml.gt     := ^>
else
  bml.echo    = echo "$1$(bml.reset)" >&2
  bml.ospath  = $1
  bml.lt     := "<"
  bml.gt     := ">"
endif
bml; := $(if $(bml.is.win),&,;)

# painful version comparison
ver.rewrap = $(strip $(eval _x:=$5)$(foreach a,0 1 2 3 4 5 6 7 8 9, \
  $(eval _x:=$(subst $1$a$2,$3$a$4,$(_x))))$(_x))
ver.expl   = $(call ver.rewrap,,, ,,$1)
ver.sep    = $(call ver.rewrap,,, , ,$1)
ver.join   = $(call ver.rewrap,, ,,,$1)
ver.split  = $(strip $(foreach a,$(subst ., ,$1),$(call ver.join,$(call ver.sep,$a))))
ver.pad    = $(strip $(if $(word $(words x $1),$2),$(call ver.pad,0 $1,$2), \
    $(if $(word $(words x $2),$1),$(call ver.pad,$1,0 $2), \
    $(subst $(bml.spc),,$1) $(subst $(bml.spc),,$2))))
ver.norm   = $(strip $(if $1$2, \
    $(call ver.pad,0 $(call ver.expl,$(firstword $1)!),0 $(call ver.expl,$(firstword $2)!)) \
    $(call ver.norm,$(wordlist 2,$(words $1),$1),$(wordlist 2,$(words $2),$2))))
ver.leq_   = $(strip $(eval _x:=$(firstword $1))$(eval _y:=$(wordlist 2,2,$1)) \
  $(eval _z:=$(wordlist 3,$(words $1),$1))$(if $(_x)$(_y), \
    $(if $(subst 0$(_x),,$(firstword $(sort 0$(_x) 0$(_y)))),, \
      $(if $(subst 0$(_x),,0$(_y)),true,$(call ver.leq_,$(_z)))),true))
ver.leq    = $(call ver.leq_,$(call ver.norm,$(call ver.split,$1),$(call ver.split,$2)))
ver.lt     = $(if $(call ver.leq,$2,$1),,true)

ver.recver  = $(strip $(if $3, \
  $(if $(call ver.leq,$1,$3),$(if $(call ver.leq,$2,$3),$(bml.green) $3, \
    $(bml.yellow) $3; recommended $2 or later), \
    $(bml.red) $3; required at least $1$(if $2,; recommended $2 or later)), \
    $(bml.red) NOT FOUND))
bml.testver = $(call bml.echo,$(bml.cyan)$1:$(call ver.recver,$2,$3,$4)$(bml.reset)$5)

bml.openp   = (
bml.closedp = )

# newline
define bml.nl


endef

# Do not delete intermediate files
.SECONDARY:

# Enable second expansion for $$(...) dependencies
.SECONDEXPANSION:

# Delete files on error
.DELETE_ON_ERROR:

.PHONY: announce-targets all html pdf scorm xml zip \
  clean clean-aux clean-html clean-pdf clean-xml clean-zip \
  detect detect-sources detect-make detect-tex detect-perl detect-latexml detect-imagemagick \
  detect-ghostscript detect-dvisvgm detect-latexmk detect-texfot detect-preview detect-zip \


all:
	@$(if $(SOURCES),,$(call bml.echo,$(bml.red) Warning: no .tex files with \documentclass found in this directory))

all:   TARGETS=$(TARGETS.ZIP) $(TARGETS.SCORM)
html:  TARGETS=$(TARGETS.HTML)
pdf:   TARGETS=$(TARGETS.PDF)
scorm: TARGETS=$(TARGETS.SCORM)
xml:   TARGETS=$(TARGETS.XML)
zip:   TARGETS=$(TARGETS.ZIP)

announce-targets:
	@$(call bml.box,Targets: $(bml.yellow) $(TARGETS))

all html pdf scorm xml zip: announce-targets $$(TARGETS)

clean: clean-aux clean-html clean-pdf clean-scorm clean-xml clean-zip

clean-aux:
	-@$(RM) $(call bml.ospath,$(foreach ext,.log .latexml.log .latexmlpost.log .fls $(bml.pathsep)LaTeXML.cache,$(SOURCES:.tex=$(ext))))
	-@$(RMDIR) $(call bml.ospath,$(DEPS_DIR) $(AUX_DIR))
clean-html:
	-@$(RMDIR) $(call bml.ospath,$(TARGETS.HTML:/index.html=))
clean-pdf:
	-@$(RM) $(call bml.ospath,$(TARGETS.PDF) $(TARGETS.PDF:.pdf=.synctex.gz))
clean-scorm:
	-@$(RM) $(call bml.ospath,$(TARGETS.SCORM))
clean-xml:
	-@$(RM) $(call bml.ospath,$(TARGETS.XML) $(patsubst %.xml,bmlimages/%-*.svg,$(TARGETS.XML)))
	-@$(RMDIR) $(call bml.ospath,$(patsubst %.xml,bmlimages/%,$(TARGETS.XML)))
clean-zip:
	-@$(RM) $(call bml.ospath,$(TARGETS.ZIP))

detect: detect-sources detect-make detect-tex detect-perl detect-latexml \
  detect-imagemagick detect-ghostscript detect-dvisvgm detect-latexmk \
  detect-texfot detect-preview detect-zip
detect-sources:
	@$(call bml.echo,$(bml.cyan)   Main files:$(if $(SOURCES) \
	  ,$(bml.green) $(SOURCES),$(bml.red) no .tex files with \documentclass found in this directory))
detect-tex:
	@$(eval tex_ver := $(subst  , ,$(patsubst $(bml.openp)%,%,$(filter $(bml.openp)%,$(subst $(bml.closedp), , \
	  $(subst $(bml.openp), $(bml.openp),$(subst $(bml.spc), ,$(shell tex -version $(bml.null)))))))))
	@$(call bml.testver,          TeX,,,$(tex_ver))
detect-make:
	@$(call bml.testver,     GNU Make,3.81,,$(MAKE_VERSION))
detect-perl:
	@$(eval perl_ver := $(subst $(bml.closedp),,$(subst $(bml.openp),,$(firstword \
	  $(filter $(bml.openp)%,$(shell perl --version $(bml.null)))))))
	@$(call bml.testver,         perl,5.8.1,,$(perl_ver), (optional))
detect-latexml:
	@$(eval latexml_ver := $(subst $(bml.closedp),,$(filter %$(bml.closedp), \
	  $(shell $(LATEXML) --VERSION 2>&1))))
	@$(call bml.testver,      LaTeXML,0.8.5,0.8.6,$(latexml_ver))
detect-imagemagick:
	@$(foreach a,Magick Magick::Q16 Magick::Q16HDRI Magick::Q8, \
	  $(if $(magick_ver),,$(eval magick_ver:=$(shell perl -MImage::$a -e "print Image::$a->VERSION" $(bml.null)))))
	@$(call bml.testver,Image::Magick,,,$(magick_ver), (required for any image handling))
detect-ghostscript:
	@$(foreach a, \
	  $(if $(bml.is.win),gswin64c gswin64 gswin32c gswin32,gs), \
	  $(if $(gs_ver),,$(eval gs_ver:=$(shell $a -v $(bml.null)))))
	@$(call bml.testver,  Ghostscript,,,$(wordlist 3,3,$(gs_ver)), (required for EPS, PDF, BookML images))
detect-dvisvgm:
	@$(call bml.testver,      dvisvgm,1.6,2.7,$(lastword $(shell dvisvgm --version $(bml.null))), (required for SVG, BookML images))
detect-latexmk:
	@$(call bml.testver,      latexmk,,,$(lastword $(shell $(LATEXMK) --version $(bml.null))))
detect-texfot:
	@$(call bml.testver,       texfot,,,$(wordlist 3,3,$(if $(TEXFOT),$(shell $(TEXFOT) --version $(bml.null)))), (optional))
detect-preview:
	@$(eval preview_loc := $(shell kpsewhich preview.sty $(bml.null)))$(eval preview_ver := $(if $(preview_loc),$(subst _,., \
	  $(subst RELEASE_,, $(filter RELEASE_%,$(subst $$Name: release_,RELEASE_,$(call bml.file,$(preview_loc))))))))
	@$(call bml.testver,  preview.sty,11.81,,$(preview_ver), (required for BookML images))
detect-zip:
	@$(eval zip_ver := $(firstword $(subst Zip_,,\
	  $(filter Zip_%,$(subst Zip$(bml.spc),Zip_,$(shell $(ZIP) -v $(bml.null)))))))
	@$(call bml.testver,          zip,,,$(zip_ver))

-include $(wildcard $(DEPS_DIR)/*.d)

$(AUX_DIR) $(DEPS_DIR):
	@$(MKDIR) "$(call bml.ospath,$@)"

# use relative paths is possible (with extra work if there are spaces)
$(subst $(bml.spc),\ ,$(CURDIR))/%.pdf %.pdf: $(AUX_DIR)/%.pdf
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$*.pdf)")
	-@$(call bml.cmd,$(CP) "$(call bml.ospath,$(AUX_DIR)/$*.synctex.gz)" "$(call bml.ospath,$*.synctex.gz)")

$(AUX_DIR)/%.pdf: will.pdf:=x
$(AUX_DIR)/%.pdf: %.tex | $(AUX_DIR) $(DEPS_DIR)
	@$(call bml.prog,pdflatex: $< → $*.pdf)
	@$(call bml.cmd,$(TEXFOT) $(TEXFOTFLAGS) $(LATEXMK) $(LATEKMKFLAGS) -norc -interaction=nonstopmode -halt-on-error -recorder \
	  -deps -deps-out="$(DEPS_DIR)/$*.d" -output-directory="$(AUX_DIR)" -g -pdf -dvi- -ps- "$<")
#	escape spaces in the filenames reeported by latexmk
	@$(PERL) -pi -e "if (s/^ +/\t/) { s/ /$(if $(bml.is.win),\\,\\\\) /g; s/^\t/    /; }" "$(DEPS_DIR)/$*.d"

%.xml: will.xml:=x
%.xml: %.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml) %.pdf
	@$(call bml.prog,latexml: $< → $@)
	@$(call bml.cmd,$(LATEXML) $(if $(call bml.grep,{bookml/bookml},$<),,--preamble=literal:$(if $(bml.is.win),\,\\)RequirePackage{bookml/bookml} \
	  ) $(LATEXMLFLAGS) $(LATEXMLEXTRAFLAGS) --destination="$@" "$<")

%/index.html: will.html:=x
%/index.html: %.xml %.pdf $(BOOKML_DEPS_HTML) $$(wildcard bmlimages/$$**.svg)
	@$(call bml.prog,latexmlpost: $< → $@)
	@$(call bml.cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl \
	  ) $(if $(SPLITAT),--splitat=$(SPLITAT)) $(LATEXMLPOSTFLAGS) $(LATEXMLPOSTEXTRAFLAGS) --destination="$@" "$<")

%.zip: will.zip:=x
%.zip: %/index.html $$(filter-out %/LaTeXML.cache,$$(call bml.rwildcard,$$*,*))
	@$(call bml.prog,zip: $(<D) → $@)
	-@$(call bml.cmd,$(RM) "$(call bml.ospath,$@)")
	@$(call bml.cmd,$(ZIP) --quiet --recurse-paths "$@" "$*" "$(ZIP_EXCLUDE)$*$(bml.pathsep)LaTeXML.cache")

# create BookML minimal manifest (a list of files generated by latexmlpost in XML format)
$(AUX_DIR)/%.manifest-xml: %/index.html $$(filter-out %/LaTeXML.cache,$$(call bml.rwildcard,$$*,*)) | $(AUX_DIR)
# call make recursively so that $(foreach) is evaluated *after* the HTML has been built
ifeq ($(BML.MANIFEST.REEVAL),)
	@$(MAKE) -f $(firstword $(MAKEFILE_LIST)) BML.MANIFEST.REEVAL=1 $@
else
	@echo $(bml.lt)manifest$(bml.gt) > $@
	$(foreach f,index.html $(filter-out index.html LaTeXML.cache,$(patsubst $*/%,%,$(call bml.rwildcard.file,$*,*))), \
	  @echo $(bml.lt)file$(bml.gt)$f$(bml.lt)/file$(bml.gt) >> $@ $(bml.nl))
	@echo $(bml.lt)/manifest$(bml.gt) >> $@
endif

$(AUX_DIR)/%/imsmanifest.xml: will.scormmanifest:=x
$(AUX_DIR)/%/imsmanifest.xml: %.xml $(AUX_DIR)/%.manifest-xml bookml/XSLT/LaTeXML-imsmanifest.xsl
	@$(call bml.prog,SCORM manifest: $< → $@)
	@$(call bml.cmd,$(LATEXMLPOST) --stylesheet=bookml/XSLT/LaTeXML-imsmanifest.xsl --destination="$@" "$<" \
	  --nodefaultresources "--xsltparameter=BML_MANIFEST:$(AUX_DIR)/$*.manifest-xml")

SCORM.%.zip: will.scorm:=x
SCORM.%.zip: %/index.html $(AUX_DIR)/%/imsmanifest.xml $$(filter-out LaTeXML.cache,$$(call bml.rwildcard,$$*,*))
	@$(call bml.prog,SCORM: $(<D) → $@)
	-@$(call bml.cmd,$(RM) "$(call bml.ospath,$@)")
	@$(call bml.cmd,cd "$(AUX_DIR)/$*") $(bml;) $(call bml.cmd,$(ZIP) --quiet "..$(bml.pathsep)..$(bml.pathsep)$@" imsmanifest.xml)
	@$(call bml.cmd,cd "$(<D)") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)$@" . "$(ZIP_EXCLUDE)LaTeXML.cache")
