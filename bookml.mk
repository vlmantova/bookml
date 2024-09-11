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
AUX_DIR    ?= auxdir
# (2) latexmk command and options
LATEXMK      ?= latexmk
LATEKMKFLAGS ?=
SYNCTEX      ?= 5 # must produce *.synctex.gz
# (3) latexml commands and options
LATEXML          ?= latexml
LATEXMLPOST      ?= latexmlpost
LATEXMLFLAGS     ?=
LATEXMLPOSTFLAGS ?= --urlstyle=file --navigationtoc=context --sourcedirectory=.
# (4) for *adding* options without changing the default ones
LATEXMLEXTRAFLAGS     ?=
LATEXMLPOSTEXTRAFLAGS ?= --pmml --mathtex
# (5) perl command
PERL ?= perl
# (6) how to split into multiple files (section, chapter, etc), set to empty string to disable splitting
SPLITAT ?= section
# (7) source files: by default, all .tex files containing a \documentclass
SOURCES ?= $(foreach f,$(wildcard *.tex),$(if $(call bml.grep,\documentclass,$(f)),$(f)))
# (8) files to be built: by default, a .zip and a SCORM.zip file for each .tex file in $(SOURCES)
TARGETS.PDF   ?= $(SOURCES:.tex=.pdf)
TARGETS.XML   ?= $(patsubst %.pdf,$(AUX_DIR)/xml/%.xml,$(TARGETS.PDF))
TARGETS.HTML  ?= $(patsubst $(AUX_DIR)/xml/%.xml,$(AUX_DIR)/html/%/index.html,$(TARGETS.XML))
TARGETS.ZIP   ?= $(patsubst $(AUX_DIR)/html/%/index.html,%.zip,$(TARGETS.HTML))
TARGETS.SCORM ?= $(patsubst $(AUX_DIR)/html/%/index.html,SCORM.%.zip,$(TARGETS.HTML))
# (9) texfot (optional, disable with TEXFOT=)
TEXFOT      ?= $(if $(call bml.which,texfot),texfot)
TEXFOTFLAGS ?= $(if $(TEXFOT),--no-stderr,)
# (10) various terminal commands: by default, use typical Windows or Unix version
bml.is.win  := $(if $(subst xWindows_NT,,x$(OS)),,true)
ifeq ($(bml.is.win),true)
  ZIP         ?= $(if $(shell where zip 2>NUL),zip,miktex-zip)
  CP          := copy
  RMDIR       := rd /s /q
  RM          := del /f /s /q
  MKDIR       := mkdir
else
  ZIP         ?= zip
  CP          := cp
  RMDIR       := rm -fr --
  RM          := rm -f --
  MKDIR       := mkdir -p --
endif
ZIP_EXCLUDE ?= -x
### END CONFIGURATION

### INTERNAL VARIABLES
BOOKML_DEPS_HTML = $(wildcard LaTeXML-html5.xsl bookml/XSLT/*.xsl \
  bookml/*.rng bookml/CSS/*.css bookml/gitbook/css/fontawesome/*.ttf \
  bookml/gitbook/css/*.css bookml/js/*.js)
BOOKML_DEPS_XML  = $(wildcard bookml/*.ltxml bookml/*.rng)

BMLGOALS = $(MAKECMDGOALS)

### UTILS
# cross-platform convenience variables
bml.openp   := (
bml.closedp := )
bml.comma   := ,
define bml.nl # newline


endef

# find if a command is available
ifeq ($(bml.is.win),true)
  bml.which = $(shell where "$1" 2>NUL)
else
  bml.which = $(shell command -v "$1")
endif
# recursively list all files and folders, or just files, within a directory (after https://stackoverflow.com/a/18258352)
bml.reclist      = $(foreach d,$(wildcard $(1:=/*)),$(call bml.reclist,$d) $d)
bml.reclist.file = $(foreach d,$(wildcard $(1:=/*)),$(eval _x:=$(call bml.reclist.file,$d))$(if $(_x),$(_x),$d)) # BUG: empty folders are interpreted as files
# backward compatible file/grep function
ifeq ($(findstring version-3.8,version-$(MAKE_VERSION)),version-3.8)
  ifeq ($(bml.is.win),true)
    bml.file = $(shell type $1)
  else
    bml.file = $(shell cat -- $1)
  endif
else
  bml.file = $(file < $1)
endif
bml.grep = $(findstring $1,$(call bml.file,$2))

# help editors detect UTF-8 encoding: ∀x.x=x

# progress output (code inspired by GMSL)
bml.spc := $(strip) $(strip)
bml.box  = $(call bml.echo,$(bml.redbg)$(bml.white) $(strip $(subst $(bml.spc)$(bml.esc)[,$(bml.esc)[,$1))$(bml.reset)$(bml.redbg) )
ifeq ($(bml.is.win),true)
  bml.cmd  = $(call bml.echo,$(bml.cyan)$1) & $1
  bml.echo = echo $1$(bml.reset)
else
  bml.cmd  = $(call bml.echo,$(bml.cyan)$1)$(subst \,\\,$1)
  bml.echo = $(info $1$(bml.reset))
endif
bml.prog = $(call bml.box,$1)

# colors
ifeq ($(if $(bml.is.win),true,$(shell tput setaf 1 >/dev/null 2>&1 && echo true)),true)
  bml.esc     := 
  bml.cyan    := $(bml.esc)[96m
  bml.cyanbg  := $(bml.esc)[46m
  bml.magenta := $(bml.esc)[95m
  bml.yellow  := $(bml.esc)[93m
  bml.green   := $(bml.esc)[92m
  bml.red     := $(bml.esc)[91m
  bml.redbg   := $(bml.esc)[41m
  bml.blue    := $(bml.esc)[34m
  bml.white   := $(bml.esc)[97m
  bml.bluebg  := $(bml.esc)[44m
  bml.reset   := $(bml.esc)[0m
endif

ifeq ($(bml.is.win),true)
  SHELL      := cmd.exe
  __ignore   := $(shell chcp 65001)
  bml.ospath  = $(subst /,$(bml.pathsep),$1)
  bml.pathsep := $(strip \)
  bml.null    := 2>NUL
  bml.lt      := ^<
  bml.gt      := ^>
  bml;        := &
else
  SHELL      := bash
  bml.ospath  = $1
  bml.pathsep := /
  bml.null    := 2>/dev/null
  bml.lt      := "<"
  bml.gt      := ">"
  bml;        := ;
endif

# painful version comparison
ver.rewrap = $(strip $(eval _x:=$5)$(foreach a,0 1 2 3 4 5 6 7 8 9, \
  $(eval _x:=$(subst $1$a$2,$3$a$4,$(_x))))$(_x))
ver.expl   = $(call ver.rewrap,,, ,,$1)   # separate consecutive digits
ver.sep    = $(call ver.rewrap,,, , ,$1)  # separate all digits
ver.join   = $(call ver.rewrap,, ,,,$1)   # join consecutive digits and following non-digit if present
ver.split  = $(strip $(foreach a,$(subst ., ,$1),$(call ver.join,$(call ver.sep,$a))))
  # split version number by . and non-digit/digit alternations
ver.pad_   = $(strip $(if $(word $(words x $1),$2),$(call ver.pad_,0 $1,$2), \
  $(if $(word $(words x $2),$1),$(call ver.pad_,$1,0 $2), \
  $(subst $(bml.spc),,$1) $(subst $(bml.spc),,$2))))
  # zero pad two sequences of digits to make them of the same length
ver.pad    = $(strip $(if $1$2, \
  $(call ver.pad_,0 $(call ver.expl,$(firstword $1)!),0 $(call ver.expl,$(firstword $2)!)) \
  $(call ver.pad,$(wordlist 2,$(words $1),$1),$(wordlist 2,$(words $2),$2))))
  # zero pad all the components of two version numbers
ver.leq_   = $(strip $(eval _x:=$(firstword $1))$(eval _y:=$(wordlist 2,2,$1)) \
  $(eval _z:=$(wordlist 3,$(words $1),$1))$(if $(_x)$(_y), \
    $(if $(subst 0$(_x),,$(firstword $(sort 0$(_x) 0$(_y)))),, \
      $(if $(subst 0$(_x),,0$(_y)),true,$(call ver.leq_,$(_z)))),true))
  # compare two split and padded version numbers
ver.leq    = $(call ver.leq_,$(call ver.pad,$(call ver.split,$1),$(call ver.split,$2)))
  # compare two verison numbers for 'less than or equal'
ver.lt     = $(if $(call ver.leq,$2,$1),,true)
  # compare two version numbers for 'less than'

# friendly message checking for minimum and recommended version number
bml.recver  = $(strip $(if $3, \
  $(if $(call ver.leq,$1,$3),$(if $(call ver.leq,$2,$3),$(bml.green) $3 OK$(bml.reset), \
    $(bml.yellow) $3; recommended $2 or later), \
    $(bml.red) $3; required at least $1$(if $2,; recommended $2 or later)), \
    $(bml.red) NOT FOUND))
bml.testver = $(call bml.echo,$(bml.cyan)$1:$(call bml.recver,$2,$3,$4)$(bml.reset)$5)

# do not delete intermediate files
.SECONDARY:

# enable second expansion for $$(...) dependencies
.SECONDEXPANSION:

# delete files on error
.DELETE_ON_ERROR:

# force recompilation
.PHONY: FORCE

# default targets
all:
	@$(if $(SOURCES),,$(call bml.echo,$(bml.red) Warning: no .tex files with \documentclass found in this directory))
.PHONY: all

all:   TARGETS=$(TARGETS.ZIP) $(TARGETS.SCORM)
html:  TARGETS=$(TARGETS.HTML)
pdf:   TARGETS=$(TARGETS.PDF)
scorm: TARGETS=$(TARGETS.SCORM)
xml:   TARGETS=$(TARGETS.XML)
zip:   TARGETS=$(TARGETS.ZIP)

announce-targets:
	@$(call bml.box,Targets: $(TARGETS))
.PHONY: announce-targets

all html pdf scorm xml zip: announce-targets $$(TARGETS)
.PHONY: all html pdf scorm xml zip

# cleanup targets
clean:  clean-aux clean-html clean-pdf clean-scorm clean-xml clean-zip
.PHONY: clean
.PHONY: clean-aux clean-html clean-pdf clean-scorm clean-xml clean-zip

clean-aux:
	-$(RMDIR) $(call bml.ospath,$(AUX_DIR))
clean-html:
	-$(RM) $(call bml.ospath,$(AUX_DIR)/latexmlaux/*.LaTeXML.db $(AUX_DIR)/latexmlaux/*.latexmlpost.log)
	-$(RMDIR) $(call bml.ospath,$(AUX_DIR)/html)
clean-pdf:
	-$(RMDIR) $(call bml.ospath,$(AUX_DIR)/pdf)
	-$(RM) $(call bml.ospath,$(TARGETS.PDF) $(TARGETS.PDF:.pdf=.synctex) $(TARGETS.PDF:.pdf=.synctex.gz))
clean-scorm:
	-$(RM) $(call bml.ospath,$(TARGETS.SCORM))
clean-xml:
	-$(RMDIR) $(call bml.ospath,$(AUX_DIR)/xml)
	-$(RM) $(call bml.ospath,$(AUX_DIR)/latexmlaux/*.latexml.log)
	-$(RM) $(call bml.ospath,$(patsubst $(AUX_DIR)/xml/%.xml,bmlimages/%-*.svg,$(TARGETS.XML)))
	-$(RMDIR) $(call bml.ospath,$(patsubst $(AUX_DIR)/xml/%.xml,bmlimages/%,$(TARGETS.XML)))
clean-zip:
	-$(RM) $(call bml.ospath,$(TARGETS.ZIP))

# check for updates (initially, Docker only)
ifdef BOOKML_VERSION
check-for-update:
	@$(if $(call ver.lt,@VERSION@,$(BOOKML_VERSION)),$(call bml.echo,$(bml.yellow)BookML update $(BOOKML_VERSION) available$(bml.comma) run `update` to install it))
.PHONY: check-for-update
endif

# version detection targets
detect: detect-sources detect-bookml detect-make detect-tex detect-perl \
  detect-latexml detect-imagemagick detect-ghostscript detect-dvisvgm \
	detect-latexmk detect-texfot detect-preview detect-zip
.PHONY: detect
.PHONY: detect-sources detect-bookml detect-make detect-tex detect-perl \
  detect-latexml detect-imagemagick detect-ghostscript detect-dvisvgm \
	detect-latexmk detect-texfot detect-preview detect-zip
detect-sources:
	@$(call bml.echo,$(bml.cyan)   Main files:$(if $(SOURCES) \
	  ,$(bml.green) $(SOURCES),$(bml.red) no .tex files with \documentclass found in this directory))
detect-bookml:
	@$(call bml.testver,       BookML,,,@VERSION@)
detect-tex:
	@$(eval tex_ver:=$(subst  , ,$(patsubst $(bml.openp)%,%,$(filter $(bml.openp)%,$(subst $(bml.closedp), , \
	  $(subst $(bml.openp), $(bml.openp),$(subst $(bml.spc), ,$(shell tex -version $(bml.null)))))))))
	@$(call bml.testver,          TeX,,,$(tex_ver))
detect-make:
	@$(call bml.testver,     GNU Make,3.81,,$(MAKE_VERSION))
detect-perl:
	@$(eval perl_ver:=$(subst $(bml.closedp),,$(subst $(bml.openp),,$(firstword \
	  $(filter $(bml.openp)%,$(shell perl --version $(bml.null)))))))
	@$(call bml.testver,         perl,5.8.1,,$(perl_ver), (optional))
detect-latexml:
	@$(eval latexml_ver:=$(subst $(bml.closedp),,$(filter %$(bml.closedp), \
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
	@$(eval dvisvgm_info:=$(shell dvisvgm -V1 $(bml.null)))
	@$(eval dvisvgm_ver:=$(firstword $(subst dvisvgm_,,$(filter dvisvgm_%,$(subst dvisvgm ,dvisvgm_,$(dvisvgm_info))))))
	@$(eval gs_ver:=$(wordlist 2,2,$(subst &, ,$(filter Ghostscript:%,$(subst &Ghostscript:, Ghostscript:,$(subst $() ,&,$(dvisvgm_info)))))))
	@$(call bml.testver,      dvisvgm,1.6,2.7,$(dvisvgm_ver), (required for SVG, BookML images))
	@$(call bml.testver,dvisvgm/libgs,,,$(gs_ver), (required for SVG, BookML images))
detect-latexmk:
	@$(call bml.testver,      latexmk,,,$(lastword $(shell $(LATEXMK) --version $(bml.null))))
detect-texfot:
	@$(call bml.testver,       texfot,,,$(wordlist 3,3,$(if $(TEXFOT),$(shell $(TEXFOT) --version $(bml.null)))), (optional))
detect-preview:
	@$(eval preview_loc:=$(shell kpsewhich preview.sty $(bml.null)))
	@$(eval preview_ver:=$(if $(preview_loc),$(subst },,$(subst _,., \
	  $(subst RELEASE_,, $(filter RELEASE_%,$(subst \def\pr@version{,RELEASE_,$(subst $$Name: release_,RELEASE_,$(call bml.file,$(preview_loc))))))))))
	@$(call bml.testver,  preview.sty,11.81,,$(preview_ver), (required for BookML images))
detect-zip:
	@$(eval zip_ver := $(firstword $(subst Zip_,,\
	  $(filter Zip_%,$(subst Zip ,Zip_,$(shell $(ZIP) -v $(bml.null)))))))
	@$(call bml.testver,          zip,,,$(zip_ver))


# create directories
$(AUX_DIR)/deps: | $(AUX_DIR)
$(AUX_DIR)/html: | $(AUX_DIR)
$(AUX_DIR)/latexmlaux: | $(AUX_DIR)
$(AUX_DIR)/pdf: | $(AUX_DIR)
$(AUX_DIR)/xml: | $(AUX_DIR)
$(AUX_DIR) $(patsubst %,$(AUX_DIR)/%,deps html latexmlaux pdf xml):
	@$(MKDIR) "$(call bml.ospath,$@)"

# copy PDF and synctex.gz files from $(AUX_DIR) to main folder
# use relative paths is possible (with extra work if there are spaces)
$(subst $(bml.spc),\ ,$(CURDIR))/%.pdf %.pdf: $(AUX_DIR)/pdf/%.pdf
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$*.pdf)")
	-@$(CP) "$(call bml.ospath,$(AUX_DIR)/$*.synctex.gz)" "$(call bml.ospath,$*.synctex.gz)"
	-@$(CP) "$(call bml.ospath,$(AUX_DIR)/$*.synctex)" "$(call bml.ospath,$*.synctex)"

# build PDF and deps files (in $(AUX_DIR))

-include $(wildcard $(AUX_DIR)/deps/*.pdfdeps)

# force rebuild if pdfdeps file is missing
$(AUX_DIR)/pdf/%.pdf: %.tex $$(if $$(wildcard $(AUX_DIR)/deps/$$*.pdfdeps),,FORCE) | $(AUX_DIR)/pdf $(AUX_DIR)/deps
	@$(call bml.prog,pdflatex: $*.tex → $*.pdf)
	@$(call bml.cmd,$(TEXFOT) $(TEXFOTFLAGS) $(LATEXMK) $(LATEKMKFLAGS) $(if $(SYNCTEX),-synctex=$(SYNCTEX),) -g -norc -interaction=nonstopmode -halt-on-error -recorder \
	  -deps -deps-out="$(AUX_DIR)/deps/$*.pdfdeps" -MP -output-directory="$(AUX_DIR)/pdf" -pdf -dvi- -ps- "$<")
	@$(PERL) -pi -e "if (s/^ +/\t/) { s/ /$(if $(bml.is.win),\\,\\\\) /g; s/^\t/    /; }" "$(AUX_DIR)/deps/$*.pdfdeps"

# build XML files
$(AUX_DIR)/xml/%.xml: %.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml) %.pdf | $(AUX_DIR)/latexmlaux $(AUX_DIR)/xml
	@$(call bml.prog,latexml: $< → $@)
	@$(call bml.cmd,$(LATEXML) $(if $(call bml.grep,{bookml/bookml},$<),,--preamble=literal:\RequirePackage{bookml/bookml} \
	  ) $(LATEXMLFLAGS) $(LATEXMLEXTRAFLAGS) --log="$(AUX_DIR)/latexmlaux/$*.latexml.log" --destination="$@" "$<")

# discover postprocessing dependencies, including bmluser/ files and alternative formats
$(AUX_DIR)/deps/%.htmldeps: $(AUX_DIR)/xml/%.xml bookml/XSLT/proc-resources.xsl bookml/xsltproc.pl | $(AUX_DIR)/deps
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-resources.xsl "$<" --output "$@" --stringparam BML_TARGET "$(AUX_DIR)/html/$*/index.html")

# build HTML and deps files

# build recursively to force inclusion of deps files
$(AUX_DIR)/html/%/index.html: $$(AUX_DIR)/xml/$$*.xml $$(BOOKML_DEPS_HTML) $$(wildcard bmlimages/$$*-*.svg) $$(wildcard bmlimages/$$*/$$*.dpth) bookml/search_index.pl bookml/XSLT/proc-text.xsl $$(if $$(filter $$@,$$(BMLGOALS)),,FORCE) | $$(AUX_DIR)/html
	@$(eval _recurse:=$(if $(filter $@,$(BMLGOALS)),,yes))
	+@$(if $(_recurse),$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$@")
	@$(if $(_recurse),,$(call bml.prog,latexmlpost: $*.xml → $*/index.html))
	-@$(if $(_recurse),,$(call bml.cmd,$(RMDIR) $(call bml.ospath,$(AUX_DIR)/html/$*)))
	@$(if $(_recurse),,$(call bml.cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  $(if $(SPLITAT),--splitat=$(SPLITAT)) --xsltparameter=BMLSEARCH:yes $(LATEXMLPOSTFLAGS) $(LATEXMLPOSTEXTRAFLAGS) \
	  --dbfile=$(AUX_DIR)/latexmlaux/"$*".LaTeXML.db --log="$(AUX_DIR)/latexmlaux/$*.latexmlpost.log" --destination="$@" "$<"))
	@$(if $(_recurse),,$(call bml.cmd,$(PERL) bookml/search_index.pl "$(AUX_DIR)/html/$*"))

$(foreach STEM,$(patsubst $(AUX_DIR)/html/%/index.html,%,$(filter $(AUX_DIR)/html/%/index.html,$(BMLGOALS))),$(eval include $(AUX_DIR)/deps/$(STEM).htmldeps))

# package HTML output and manifest into SCORM package
SCORM.%.zip: $(AUX_DIR)/html/%/imsmanifest.xml
	@$(call bml.prog,SCORM: $* → $@)
	-@$(call bml.cmd,$(RM) "$(call bml.ospath,$@)")
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)html$(bml.pathsep)$*") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)..$(bml.pathsep)..$(bml.pathsep)$@" . "$(ZIP_EXCLUDE)LaTeXML.cache")

# package HTML output into zip file
%.zip: $$(AUX_DIR)/html/$$*/index.html $$(filter-out $$(AUX_DIR)/html/$$*/imsmanifest.xml,$$(filter-out $$(AUX_DIR)/html/$$*/LaTeXML.cache,$$(call bml.reclist.file,$$*)))
	@$(call bml.prog,zip: $(AUX_DIR)/html/$* → $@)
	-@$(call bml.cmd,$(RM) "$(call bml.ospath,$@)")
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)html") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)..$(bml.pathsep)$@" "$*" "$(ZIP_EXCLUDE)$*$(bml.pathsep)LaTeXML.cache" "$(ZIP_EXCLUDE)$*$(bml.pathsep)imsmanifest.xml")

# create BookML minimal manifest (a list of files generated by latexmlpost in XML format)
# build recursively to evaluate $(bml.reclist.file) *after* index.html has been built
$(AUX_DIR)/latexmlaux/%.manifest: $$(AUX_DIR)/html/$$*/index.html $$(filter-out $$(AUX_DIR)/html/$$*/imsmanifest.xml,$$(filter-out $$(AUX_DIR)/html/$$*/LaTeXML.cache,$$(call bml.reclist.file,$$*))) | $$(AUX_DIR)/latexmlaux
	@$(eval _recurse:=$(if $(filter $@,$(BMLGOALS)),,yes))
	+@$(if $(_recurse),$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$@")
	@$(if $(_recurse),,echo $(bml.lt)manifest$(bml.gt) > $@)
	@$(if $(_recurse),,$(foreach f,index.html $(filter-out index.html LaTeXML.cache,$(patsubst $(AUX_DIR)/html/$*/%,%,$(call bml.reclist.file,$(AUX_DIR)/html/$*))), \
	  echo $(bml.lt)file$(bml.gt)$f$(bml.lt)/file$(bml.gt) >> $@$(bml.nl)))
	@$(if $(_recurse),,echo $(bml.lt)/manifest$(bml.gt) >> $@)

# create SCORM manifest
$(AUX_DIR)/html/%/imsmanifest.xml: $(AUX_DIR)/xml/%.xml $(AUX_DIR)/latexmlaux/%.manifest bookml/XSLT/proc-imsmanifest.xsl bookml/xsltproc.pl | $(AUX_DIR)/html
	@$(call bml.prog,SCORM manifest: $*.xml → $@)
	@$(MKDIR) "$(call bml.ospath,$(AUX_DIR)/$*)"
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-imsmanifest.xsl "$<" --output "$@" \
	   --stringparam BML_MANIFEST "../latexmlaux/$*.manifest")
