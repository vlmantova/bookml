# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-26  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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

include bookml/bml-utils.mk
include bookml/bml-print.mk

### CONFIGURATION
# Configure these variables assigning the desired value anywhere inside
# 'GNUmakefile' with the sole exception of 'AUX_DIR', which must be configured
# BEFORE 'include bookml/bookml.mk'.
#
# You can extend a variable with the operator +=, but only AFTER the line
# 'include bookml/bookml.mk'.
#
# Add 'file_' to the variable name to replace its value for the outputs of
# 'file.tex' only. For *FLAGS variables, the content of the 'file_' variable
# is appended to the global value rather than replacing it.
#
# For instance, the following moves the AUX_DIR to another folder, and does not
# split HTML files into pages, except for notes.tex, which gets split by
# by section. Moreover, notes.pdf is compiled with LuaTeX instead of LaTeX.
#
# AUX_DIR = $(HOME)/Documents/bookml-outputs/example
#
# WARNING: AUX_DIR cannot contain spaces!!!
#
# include bookml/bookml.mk
# SPLITAT=
# notes_SPLITAT=section
# notes_LATEXMKFLAGS+=-lualatex

# location of all outputs and intermediary files
# must be set before 'include bookml/bookml.mk'
AUX_DIR ?= auxdir

$(if $(filter-out 1,$(words $(AUX_DIR))),$(call bml.print.error,the variable AUX_DIR cannot contain spaces nor be empty: AUX_DIR='$(AUX_DIR)'))

# source files
# by default, all .tex files containing a \documentclass
SOURCES ?= $(bml.autosources)

# formats: possible values are pdf, scorm, zip (and secretly html, xml)
# by default, build SCORM.*.zip and *.zip files
FORMATS ?= scorm zip

# files to be built
# by default, the formats requested in FORMATS for each .tex file in SOURCE
TARGETS.PDF   ?= $(sort $(call bml.utils.filtersubst,%.tex,%.pdf,$(SOURCES)))
TARGETS.XML   ?= $(sort $(call bml.utils.filtersubst,%.tex,$(AUX_DIR)/xml/%.xml,$(SOURCES)))
TARGETS.HTML  ?= $(patsubst $(AUX_DIR)/xml/%.xml,$(AUX_DIR)/html/%/index.html,$(TARGETS.XML))
TARGETS.SCORM ?= $(patsubst $(AUX_DIR)/html/%/index.html,SCORM.%.zip,$(TARGETS.HTML))
TARGETS.ZIP   ?= $(patsubst $(AUX_DIR)/html/%/index.html,%.zip,$(TARGETS.HTML))
TARGETS       += $(bml.autotargets)

# the following variables can be customised by prefixing them with 'file_'
# latexmk command and options
LATEXMK      ?= latexmk
LATEXMKFLAGS ?=
SYNCTEX      ?= 5 # must produce *.synctex.gz

# latexml commands and options
LATEXML          ?= latexml
LATEXMLPOST      ?= latexmlpost
LATEXMLFLAGS     ?=
LATEXMLPOSTFLAGS ?=

# dvisvgm command and options
DVISVGM      ?= $(if $(call bml.utils.which,dvisvgm),$(eval DVISVGM:=dvisvgm)dvisvgm,$(eval DVISVGM:=))
DVISVGMFLAGS ?= --no-fonts --optimize

# inkscape command and options
INKSCAPE      ?= $(if $(call bml.utils.which,inkscape),$(eval INKSCAPE:=inkscape)inkscape,$(eval INKSCAPE:=))
INKSCAPEFLAGS ?= --without-gui

# mutool command and options
MUTOOL      ?= $(if $(call bml.utils.which,mutool),$(eval MUTOOL:=mutool)mutool,$(eval MUTOOL:=))
MUTOOLFLAGS ?=

# mutool command and options
PDFTOCAIRO      ?= $(if $(call bml.utils.which,pdftocairo),$(eval PDFTOCAIRO:=pdftocairo)pdftocairo,$(eval PDFTOCAIRO:=))
PDFTOCAIROFLAGS ?=

# choice of EPS/PDF to SVG converter
# dvisvgm, then inkscape, if available
EPSTOSVG_CONVERTER ?= auto
# mutool, then pdftocairo, dvisvgm, inkscape if available
PDFTOSVG_CONVERTER ?= auto

# how to split into multiple files (section, chapter, etc)
# set to empty string to disable splitting
SPLITAT ?= section

# texfot (optional, disable with TEXFOT=)
TEXFOT      ?= $(if $(call bml.utils.which,texfot),$(eval TEXFOT:=texfot)texfot,$(eval TEXFOT:=))
TEXFOTFLAGS ?= $(if $(call bml.utils.autovar,TEXFOT),--no-stderr,)

# the following variables CANNOT be customised with 'file_'
# perl command
PERL ?= perl

# various terminal commands: by default, use typical Windows or Unix version
ifneq ($(bml.utils.iswin),)
  ZIP          ?= $(if $(call bml.utils.which,zip),$(eval ZIP:=zip)zip,$(eval ZIP:=miktex-zip)miktex-zip)
  ifndef UNZIP
    UNZIP       = $(if $(call bml.utils.which,tar),$(eval UNZIP:=tar)tar,$(eval UNZIP:=))
    UNZIPFLAGS ?= -x -f
  endif
  CP           := copy
  MV           := move
  RMDIR        := rd /s /q
  RM           := del /f /s /q
  MKDIR        := mkdir
  ROBOCOPY     := robocopy
else
  ZIP          ?= zip
  ifndef UNZIP
    UNZIP       = $(if $(call bml.utils.which,unzip),$(eval UNZIP:=unzip)unzip,$(eval UNZIP:=))
    UNZIPFLAGS ?= -o
  endif
  CP           := cp
  MV           := mv
  RMDIR        := rm -fr --
  RM           := rm -f --
  MKDIR        := mkdir -p --
  TOUCH        := touch
endif
ZIP_EXCLUDE ?= -x
CURL        ?= $(if $(call bml.utils.which,curl),$(eval CURL:=curl)curl,$(eval CURL:=))

### END CONFIGURATION

include bookml/bml-version.mk
include bookml/bml-config.mk
include bookml/bml-detect.mk
include bookml/bml-print.mk

### INTERNAL VARIABLES
# default value of TARGETS
bml.formats.cmd := $(filter html pdf scorm xml zip,$(bml.utils.makecmdgoals))
bml.formats      = $(sort $(if $(filter all,$(bml.utils.makecmdgoals)),$(FORMATS)) $(bml.formats.cmd))
bml.autotargets  = $(sort $(filter-out all html pdf scorm xml zip clean clean-% detect detect-% check-for-update update,$(bml.utils.makecmdgoals)) \
  $(if $(filter html,$(bml.formats)),$(TARGETS.HTML)) \
  $(if $(filter pdf,$(bml.formats)),$(TARGETS.PDF)) \
  $(if $(filter scorm,$(bml.formats)),$(TARGETS.SCORM)) \
  $(if $(filter xml,$(bml.formats)),$(TARGETS.XML)) \
  $(if $(filter zip,$(bml.formats)),$(TARGETS.ZIP)))

# default value of SOURCES, but computed only if necessary
ifndef bml.autosources
  bml.autosources :=
  ifeq ("$(value SOURCES)","$$(bml.autosources)")
    ifneq ($(or $(and $(filter all,$(bml.utils.makecmdgoals)),$(filter "$(value TARGETS)","$$(bml.autotargets)"))),\
             $(filter detect-sources,$(bml.utils.makecmdgoals),\
             $(filter-out all check-for-update detect-% update %/ %.html %.pdf %.svg %.xml SCORM.%.zip %.zip $(AUX_DIR)/%,$(bml.utils.makecmdgoals))),)
      bml.allsources := $(wildcard *.tex)
      $(if $(filter-out %.tex,$(bml.allsources)),$(call bml.print.warning,Some .tex files have spaces in their names, which is not supported!))
      bml.autosources := $(sort $(foreach source,$(filter %.tex,$(bml.allsources)),$(if $(call bml.utils.grep,\documentclass,$(source)),$(source))))
    endif
  endif
endif

include bookml/bml-deps.mk

# backward compatibility flag
LATEKMKFLAGS          ?=
LATEXMLEXTRAFLAGS     ?=
LATEXMLPOSTEXTRAFLAGS ?=

# flags added by deps makefiles, default provided to silence warnings
LATEXMLPOSTAUTOFLAGS  ?=

BOOKML_DEPS_DEPS        = bookml/bookml.pm bookml/deps.pl
BOOKML_DEPS_PDF         = bookml/bookml.pm bookml/xraux.pl
BOOKML_DEPS_HTML        = $(wildcard LaTeXML-html5.xsl bookml/XSLT/*.xsl) bookml/bookml.pm bookml/xsltproc.pl bookml/search_index.pl
BOOKML_DEPS_XML         = bookml/XSLT/proc-preprocess-xml.xsl bookml/XSLT/utils.xsl bookml/bookml.pm bookml/xsltproc.pl
BOOKML_DEPS_IMSMANIFEST = bookml/XSLT/proc-imsmanifest.xsl bookml/bookml.pm bookml/xsltproc.pl
BOOKML_DEPS_MANIFEST    = bookml/bookml.pm bookml/manifest.pl
BOOKML_DEPS_HTMLDEPS    = bookml/XSLT/proc-resources.xsl bookml/XSLT/utils.xsl bookml/bookml.pm bookml/xsltproc.pl
BOOKML_DEPS_AUTOSVG     = bookml/XSLT/proc-svg.xsl bookml/XSLT/utils.xsl bookml/bookml.pm bookml/xsltproc.pl

# do not delete intermediate files
.SECONDARY:

# delete files on error
.DELETE_ON_ERROR:

# force recompilation when needed
.PHONY: FORCE

### MAIN TARGETS
# use ':' to silence 'Nothing to be done' if something actually happened
all html pdf scorm xml zip: %:
	@$(if $(SOURCES)$^,,$$(call bml.print.warning,Warning: no .tex files with \documentclass found in this directory))
	@$(if $(MAKE_RESTARTS),:)

all:   $(TARGETS)
html:  $(TARGETS.HTML)
pdf:   $(TARGETS.PDF)
scorm: $(TARGETS.SCORM)
xml:   $(TARGETS.XML)
zip:   $(TARGETS.ZIP)
.PHONY: all html pdf scorm xml zip

### ANNOUNCE TARGETS
bml.ordinal = $1$(if $(filter %0 %11 %12 %13 %4 %5 %6 %7 %8 %9,$1),th,$(if $(filter %1,$1),st,$(if $(filter %2,$1),nd,$(if $(filter %3,$1),rd))))
ifeq ($(filter clean clean-% detect detect-%,$(bml.utils.makecmdgoals)),)
  $(if $(filter-out undefined,$(origin MAKE_RESTARTS)),$(call bml.print.yellowbox_,$(call bml.ordinal,$(MAKE_RESTARTS)) make restart),$(call bml.print.redbox_,Targets: $(sort $(TARGETS))$(if $(filter 0,$(MAKELEVEL)),, (recursion level $(MAKELEVEL)))))
else ifneq ($(filter clean clean-%,$(bml.utils.makecmdgoals)),)
  $(call bml.print.redbox_,Cleaning: $(sort $(patsubst clean,all,$(patsubst clean-%,%,$(bml.utils.makecmdgoals))))$(if $(filter-out undefined,$(origin MAKE_RESTARTS)), (further pass $(MAKE_RESTARTS)))$(if $(filter 0,$(MAKELEVEL)),, (recursion level $(MAKELEVEL))))
endif

### CLEANUP TARGETS
clean:  clean-aux clean-deps clean-html clean-pdf clean-scorm clean-svg clean-xml clean-zip
.PHONY: clean
.PHONY: clean-aux clean-deps clean-html clean-pdf clean-scorm clean-svg clean-xml clean-zip

clean-aux:
	$(call bml.utils.rmdir,$(AUX_DIR))
clean-deps:
	$(call bml.utils.rmdir,$(AUX_DIR)/deps)
clean-html:
	-$(RM) $(call bml.utils.ospath,$(AUX_DIR)/latexmlaux/*.LaTeXML.db $(AUX_DIR)/latexmlaux/*.latexmlpost.log)
	$(call bml.utils.rmdir,$(AUX_DIR)/html)
clean-pdf:
	-$(call bml.utils.rmdir,$(AUX_DIR)/pdf)
	-$(RM) $(call bml.utils.ospath,$(TARGETS.PDF) $(TARGETS.PDF:.pdf=.synctex) $(TARGETS.PDF:.pdf=.synctex.gz))
clean-scorm:
	-$(call bml.utils.rmdir,$(AUX_DIR)/scorm)
	-$(RM) $(call bml.utils.ospath,$(TARGETS.SCORM))
clean-svg:
	$(call bml.utils.rmdir,bmlimages/svg)
clean-xml:
	-$(call bml.utils.rmdir,$(AUX_DIR)/xml)
	-$(call bml.utils.rmdir,bmlimages/dvi)
	-$(RM) $(call bml.utils.ospath,$(AUX_DIR)/latexmlaux/*.latexml.log $(AUX_DIR)/latexmlaux/*.latexml.log)
	-$(RM) $(call bml.utils.ospath,$(patsubst $(AUX_DIR)/xml/%.xml,bmlimages/%-*.svg,$(TARGETS.XML)))
clean-zip:
	$(call bml.utils.rmdir,$(AUX_DIR)/zip)
	-$(RM) $(call bml.utils.ospath,$(TARGETS.ZIP))

### DIRECTORIES
# suffix /./ is required for compatibility with GNU Make 3.81

# generate all possible subfolders so that \include{subfolder/...} can write its aux files
bml.curleafdirs  := $(call bml.utils.leafdirs,$(filter-out $(AUX_DIR)/./ bookml/./ bmlimages/./,$(wildcard */./)))
bml.pdfleafdirs  := $(patsubst %,$(AUX_DIR)/pdf/%,$(bml.curleafdirs))
bml.builtpdfdirs := $(patsubst $(AUX_DIR)/pdf/%,%,$(filter %/,$(call bml.utils.tree,$(AUX_DIR)/pdf)))

# generating the $(AUX_DIR)/pdf/ tree can take time, let the user know
# important: the target must not exist to ensure its recipe always runs, but
# not be true .PHONY or the depending recipes will also run every time
$(filter-out $(bml.builtpdfdirs),$(bml.curleafdirs)):
$(AUX_DIR)/PHONY/beforedirs: $(filter-out $(bml.builtpdfdirs),$(bml.curleafdirs))
	@$(call bml.print.echo,$(bml.print.cyan)creating $(words $?) folder$(if $(filter-out 1,$(words $?)),s) in $$(AUX_DIR)/pdf in case $(if $(filter-out 1,$(words $?)),they are,it is) needed by '\include'; this may take some time)

$(AUX_DIR)/pdf/%/./: | $(AUX_DIR)/PHONY/beforedirs
	@$(call bml.utils.mkdir,$@)

$(AUX_DIR)/%/./:
	@$(call bml.utils.mkdir,$@)

bmlimages/svg/%/./:
	@$(call bml.utils.mkdir,$@)

bmlimages/svg/./ $(AUX_DIR)/./:
	@$(call bml.utils.mkdir,$@)

### RECIPE WRAPPER
# - record the update for the make call in bml-deps.mk
# - save the new target-specific configuration if it has changed
# - save the timestamp of the start of the build
define bml.buildbegin
	@$(bml.deps.recordupdate)
	@$(bml.config.save)
	@$(bml.utils.savetimestamp)
endef
# - after the target is built, resets its timestamp to the start of the build
define bml.buildend
	@$(bml.utils.restoretimestamp)
endef

# each recipe using the wrapper must have
# - before the recipe, a call $(call bml.config.set,FORMAT,flags[,...[,EXT]])
#   determining which variables, and possibly other data, is part of its
#   configuration
# - prerequisite $$(call bml.config.prereq,FORMAT)
# - order-only prerequisite $(call bml.config.predir,FORMAT)
# bml.config.prereq requires second expansion

.SECONDEXPANSION:

### PDF

# typo LATEKMKFLAGS preserved for backwards compatibility
$(call bml.config.set,pdf,LATEXMKFLAGS LATEKMKFLAGS)

# the recipe also produces .aux, .fdb_latexmk, .fls, .log
# generate .xraux too as it would not get updated otherwise
# generate .mk to skip a step on the next restart
# .xraux is an order-only dependency to prevent building it in parallel
$(AUX_DIR)/pdf/%.pdf: %.tex $(BOOKML_DEPS_PDF) $$(call bml.config.prereq,pdf) \
  | $(AUX_DIR)/pdf/%.xraux $$(@D)/./ $(bml.pdfleafdirs) $(bml.utils.tsprereq) $(call bml.config.predir,pdf)
	@$(bml.buildbegin)
	@$(call bml.print.recipe,latexmk,$*.tex,$*.pdf)
	@$(call bml.print.cmd,$(if $(call bml.utils.autovar,TEXFOT),$(call bml.utils.autovar,TEXFOT) $(call bml.utils.autovar,TEXFOTFLAGS)) \
	  $(call bml.utils.autovar,LATEXMK) -pdf -dvi- -ps- $(if $(call bml.utils.autovar,SYNCTEX),-synctex=$(call bml.utils.autovar,SYNCTEX),) \
	  $(call bml.utils.autovar,LATEKMKFLAGS) $(call bml.utils.autovar,LATEXMKFLAGS) \
	  -g -norc -interaction=nonstopmode -halt-on-error -file-line-error -recorder \
	  $(call bml.utils.escape2args,-output-directory=$(@D),$<))
	@$(bml.buildend)
	@$(PERL) bookml/xraux.pl --output $(call bml.utils.escape2args,$(AUX_DIR)/pdf/$*.xraux,$(AUX_DIR)/pdf/$*.aux)
	@$(PERL) bookml/deps.pl $(call bml.utils.escape6args,-a=$(AUX_DIR),-o=$(AUX_DIR)/deps/$*.tex/pdf.mk,$(AUX_DIR)/pdf/$*.fdb_latexmk,$(AUX_DIR)/pdf/$*.fls,$(AUX_DIR)/pdf/$*.log,$(AUX_DIR)/pdf/$*.xraux)

# if .aux, .fls, .log, .pdf are missing, force rebuilding the PDF
define bml.forcepdf
ifeq ($(and $(wildcard $1.aux),$(wildcard $1.fdb_latexmk),$(wildcard $1.fls),$(wildcard $1.log),$(wildcard $1.pdf)),)
$1.pdf: FORCE
endif
endef

$(foreach target,$(call bml.utils.filtersubst,$(AUX_DIR)/deps/%.tex/pdf.mk,$(AUX_DIR)/pdf/%,$(bml.deps.rebuild)),$(eval $(call bml.forcepdf,$(target))))

# restore .xraux if missing and record the update for the benefit of bml-deps
# .tex order-only dependency helps avoid issues with non-existing files
$(AUX_DIR)/pdf/%.xraux: $(BOOKML_DEPS_PDF) | %.tex
	@$(bml.deps.recordupdate)
	@$(if $(wildcard $(AUX_DIR)/pdf/$*.aux),$(PERL) bookml/xraux.pl --force --output $(call bml.utils.escape2args,$(AUX_DIR)/pdf/$*.xraux,$(AUX_DIR)/pdf/$*.aux))

# rebuild the deps makefiles from the log files
# only when needed since .log files may exist from failed PDF builds
# fragility issue: deps.pl expects .fdb_latexmk from *other* files to be in
# $(AUX_DIR)/pdf to detect xr dependencies correctly; removing some files in
# $(AUX_DIR)/pdf and in $(AUX_DIR)/deps may lead to an inconsistent state
$(AUX_DIR)/pdf/%.fdb_latexmk $(AUX_DIR)/pdf/%.fls $(AUX_DIR)/pdf/%.log: $(AUX_DIR)/pdf/%.pdf ;
$(filter $(AUX_DIR)/deps/%.tex/pdf.mk,$(bml.deps.rebuild)): $(AUX_DIR)/deps/%.tex/pdf.mk: $(AUX_DIR)/pdf/%.fdb_latexmk $(AUX_DIR)/pdf/%.fls $(AUX_DIR)/pdf/%.log $(AUX_DIR)/pdf/%.xraux $(BOOKML_DEPS_DEPS)
	@$(if $(wildcard $(AUX_DIR)/pdf/$*.xraux),$(PERL) bookml/deps.pl $(call bml.utils.escape6args,-a=$(AUX_DIR),-o=$@,$(AUX_DIR)/pdf/$*.fdb_latexmk,$(AUX_DIR)/pdf/$*.fls,$(AUX_DIR)/pdf/$*.log,$(AUX_DIR)/pdf/$*.xraux))

### XML

$(call bml.config.set,xml,LATEXMLFLAGS LATEXMLEXTRAFLAGS)

# the recipe also produces .latexml.log
# attrib -r works around an issue where Windows sets the READONLY attribute on
# the xml folder (common on cloud drives) and LaTeXML *believes it*
# generate .mk to skip a step on the next restart
$(AUX_DIR)/xml/%.xml: %.tex $$(call bml.config.prereq,xml) \
  | $$(@D)/./ $(bml.utils.tsprereq) $(call bml.config.predir,xml)
	@$(bml.buildbegin)
	@$(call bml.print.recipe,latexml,$<,$*.xml)
	@$(if $(bml.utils.iswin),attrib -r $(call bml.utils.escapearg,$(call bml.utils.ospath,$(@D))))
	@$(call bml.print.cmd,$(call bml.utils.autovar,LATEXML) $(call bml.utils.escapearg,--preamble=literal:\RequirePackage{bookml/bookml-init}) \
	  $(call bml.utils.autovar,LATEXMLFLAGS) $(call bml.utils.autovar,LATEXMLEXTRAFLAGS) \
	  $(call bml.utils.escape3args,--log=$(AUX_DIR)/latexmlaux/$*.latexml.log,--destination=$(AUX_DIR)/xml/$*.xml,$<))
	@$(bml.buildend)
	@$(PERL) bookml/deps.pl $(call bml.utils.escape3args,-a=$(AUX_DIR),-o=$(AUX_DIR)/deps/$*.tex/xml.mk,$(AUX_DIR)/latexmlaux/$*.latexml.log)

# if .latexml.log is missing, force rebuilding the XML
define bml.forcexml
ifeq ($(and $(wildcard $(AUX_DIR)/latexmlaux/$1.latexml.log),$(wildcard $(AUX_DIR)/xml/$1.xml)),)
$(AUX_DIR)/xml/$1.xml: FORCE
endif
endef

$(foreach target,$(call bml.utils.filtersubst,$(AUX_DIR)/deps/%.tex/xml.mk,%,$(bml.deps.rebuild)),$(eval $(call bml.forcexml,$(target))))

# rebuild the deps makefiles from the log file
$(AUX_DIR)/latexmlaux/%.latexml.log: $(AUX_DIR)/xml/%.xml ;
$(filter $(AUX_DIR)/deps/%.tex/xml.mk,$(bml.deps.rebuild)): $(AUX_DIR)/deps/%.tex/xml.mk: $(AUX_DIR)/latexmlaux/%.latexml.log $(BOOKML_DEPS_DEPS)
	@$(PERL) bookml/deps.pl $(call bml.utils.escape3args,-a=$(AUX_DIR),-o=$@,$<)

# additional preprocessing to XML files (for EPS/PDF to SVG conversion)
$(call bml.config.set,preprocessed-xml,,\# AUTOSVG xslt parameter set to '$$(if $$(PDFTOSVG_CONVERTER),pdf) $$(if $$(EPSTOSVG_CONVERTER),eps)')

$(AUX_DIR)/xml/%.preprocessed-xml: $(AUX_DIR)/xml/%.xml $(BOOKML_DEPS_XML) $$(call bml.config.prereq,preprocessed-xml) \
  | $(bml.utils.tsprereq) $(call bml.config.predir,preprocessed-xml)
	@$(bml.buildbegin)
	@$(call bml.print.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-preprocess-xml.xsl --stringparam AUTOSVG $(call bml.utils.escape3args,$(if $(PDFTOSVG_CONVERTER),pdf) $(if $(EPSTOSVG_CONVERTER),eps),$<,--output=$@))
	@$(bml.buildend)

### HTML

# the recipe also produces LaTeXML.cache, .LaTeXML.db
# delete LaTeXML.cache to keep the output clean
# delete .LaTeXML.db to work around latexmlpost getting stuck when the
# splitting options change
$(call bml.config.set,html,LATEXMLPOSTFLAGS LATEXMLPOSTEXTRAFLAGS SPLITAT)

$(AUX_DIR)/html/%/index.html: $(AUX_DIR)/xml/%.preprocessed-xml $(BOOKML_DEPS_HTML) $$(call bml.config.prereq,html) \
  | $(bml.utils.tsprereq) $(call bml.config.predir,html)
	@$(bml.buildbegin)
	@$(call bml.print.recipe,latexmlpost,$*.xml,$(AUX_DIR)/html/$*/index.html)
	@$(call bml.utils.rmdir,$(AUX_DIR)/html/$*)
	@$(call bml.print.cmd,$(call bml.utils.autovar,LATEXMLPOST) \
	  $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  $(if $(call bml.utils.autovar,SPLITAT),--splitat=$(call bml.utils.autovar,SPLITAT)) \
	  --urlstyle=file --pmml --mathtex \
	  $(call bml.utils.autovar,LATEXMLPOSTFLAGS) $(call bml.utils.autovar,LATEXMLPOSTEXTRAFLAGS) \
	  --xsltparameter=BMLSEARCH:yes --sourcedirectory=. $(LATEXMLPOSTAUTOFLAGS) \
	  $(call bml.utils.escape4args,--dbfile=$(AUX_DIR)/latexmlaux/$*.LaTeXML.db,--log=$(AUX_DIR)/latexmlaux/$*.latexmlpost.log,--destination=$@,$<))
	@$(call bml.utils.rm,$(AUX_DIR)/html/$*/LaTeXML.cache)
	@$(call bml.utils.rm,$(AUX_DIR)/latexmlaux/$*.LaTeXML.db)
	@$(call bml.print.cmd,$(PERL) bookml/search_index.pl $(call bml.utils.escapearg,$(AUX_DIR)/html/$*))
	@$(bml.buildend)

# rebuild the deps makefiles from the preprocessed XML files
$(filter $(AUX_DIR)/deps/%.tex/html.mk,$(bml.deps.rebuild)): $(AUX_DIR)/deps/%.tex/html.mk: $(AUX_DIR)/xml/%.preprocessed-xml $(BOOKML_DEPS_HTMLDEPS)
	@$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-resources.xsl --stringparam BML_JOB $(call bml.utils.escape3args,$*,$<,--output=$@)

# prevent make from trying to build the files in $(AUX_DIR)/html for which we have no recipe
bml.htmltree := $(call bml.utils.tree,$(wildcard $(AUX_DIR)/html/*))

bml.htmltree.noindex := $(filter-out $(AUX_DIR)/html/%/index.html,$(bml.htmltree)) \
  $(foreach filename,$(filter $(AUX_DIR)/html/%/index.html,$(bml.htmltree)),$(if $(findstring /,$(patsubst $(AUX_DIR)/html/%/index.html,%,$(filename))),$(filename)))
bml.htmltree.for      = $(filter $(AUX_DIR)/html/$1/%,$(bml.htmltree))
$(bml.htmltree.noindex):

### EPS/PDF TO SVG

# pick out source prerequisites (which may or may not be $<) and deduce page
# number from source and output filename
bml.autosvg.source = $(filter-out $(BOOKML_DEPS_AUTOSVG) BML_UPDATED_CONFIG_%,$^)
bml.autosvg.page   = $(if $(filter $(notdir $(bml.autosvg.source)),$(notdir $(@D))),$(patsubst p%.svg,%,$(@F)),1)

# EPS to SVG recipe
bml.autosvg.epsconverter = $(if $(filter auto,$(call bml.utils.autovar,EPSTOSVG_CONVERTER)),$(if $(DVISVGM),dvisvgm,$(if $(INKSCAPE),inkscape,not-found)),$(call bml.utils.autovar,EPSTOSVG_CONVERTER))
define bml.autosvg.epsrecipe
	@$(bml.config.save)
	@$(if $(filter-out bmlimages/svg,$(@D)),$(call bml.utils.mkdir,$(@D)))
	@$(if $(filter dvisvgm,$(bml.autosvg.epsconverter)),$(call bml.print.cmd,$(DVISVGM) $(call bml.utils.autovar,DVISVGMFLAGS) --eps $(call bml.utils.escape2args,$(bml.autosvg.source),--output=$@)))
	@$(if $(filter inkscape,$(bml.autosvg.epsconverter)),$(call bml.print.cmd,$(INKSCAPE) $(call bml.utils.autovar,INKSCAPEFLAGS) $(call bml.utils.escape2args,--export-filename=$@,$(bml.autosvg.source))))
	@$(if $(filter-out dvisvgm inkscape,$(bml.autosvg.epsconverter)),$(call bml.print.warning,Option EPSTOSVG_CONVERTER: value '$(bml.autosvg.epsconverter)' not recognised. '$(bml.autosvg.source)' will not be converted to SVG.),	@$(call bml.print.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl --stringparam SVGCONVERTER $(bml.autosvg.epsconverter) $(call bml.utils.escape2args,$@,--output=$@)))
endef

# PDF to SVG recipe
bml.autosvg.pdfconverter = $(if $(filter auto,$(call bml.utils.autovar,PDFTOSVG_CONVERTER)),$(if $(MUTOOL),mutool,$(if $(PDFTOCAIRO),pdftocairo,$(if $(INKSCAPE),inkscape,$(if $(DVISVGM),dvisvgm,not-found)))),$(call bml.utils.autovar,PDFTOSVG_CONVERTER))
# annoyingly, some versions of mutool will mangle the file name with a page
# number regardless of what was requested! and they will also return invalid
# SVGs if no page is requested, so '>' must be used
define bml.autosvg.pdfrecipe
	@$(bml.config.save)
	@$(if $(filter dvisvgm,$(bml.autosvg.pdfconverter)),$(call bml.print.cmd,$(DVISVGM) $(call bml.utils.autovar,DVISVGMFLAGS) --pdf --page=$(bml.autosvg.page) $(call bml.utils.escape2args,$(bml.autosvg.source),--output=$@)))
	@$(if $(filter inkscape,$(bml.autosvg.pdfconverter)),$(call bml.print.cmd,$(INKSCAPE) $(call bml.utils.autovar,INKSCAPEFLAGS) --pages=$(bml.autosvg.page) $(call bml.utils.escape2args,--export-filename=$@,$(bml.autosvg.source))))
	@$(if $(filter mutool,$(bml.autosvg.pdfconverter)),$(call bml.print.cmd,$(MUTOOL) draw $(call bml.utils.autovar,MUTOOLFLAGS) -F svg $(call bml.utils.escapearg,$(bml.autosvg.source)) $(bml.autosvg.page) > $(call bml.utils.escapearg,$(call bml.utils.ospath,$@))))
	@$(if $(filter pdftocairo,$(bml.autosvg.pdfconverter)),$(call bml.print.cmd,$(PDFTOCAIRO) $(call bml.utils.autovar,PDFTOCAIROFLAGS) -f $(bml.autosvg.page) -svg $(call bml.utils.escape2args,$(bml.autosvg.source),$@)))
	@$(if $(filter-out dvisvgm inkscape mutool pdftocairo,$(bml.autosvg.pdfconverter)),$(call bml.print.warning,Option PDFTOSVG_CONVERTER: value '$(bml.autosvg.pdfconverter)' not recognised. '$(bml.autosvg.source)' will not be converted to SVG.),$(call bml.print.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl --stringparam SVGCONVERTER $(bml.autosvg.pdfconverter) $(call bml.utils.escape2args,$@,--output=$@)))
endef

# automatically pick between PDF and EPS recipe
bml.autosvg.recipe = $(if $(filter %.pdf %.PDF,$^),$(bml.autosvg.pdfrecipe),$(bml.autosvg.epsrecipe))

$(call bml.config.set,epstosvg,EPSTOSVG_CONVERTER \
  $$(if $$(filter dvisvgm,$$(bml.autosvg.epsconverter)),DVISVGMFLAGS, \
    $$(if $$(filter inkscape,$$(bml.autosvg.epsconverter)),INKSCAPEFLAGS,DVISVGMFLAGS INKSCAPEFLAGS)),,eps)
$(call bml.config.set,pdftosvg,PDFTOSVG_CONVERTER \
  $$(if $$(filter dvisvgm,$$(bml.autosvg.pdfconverter)),DVISVGMFLAGS, \
    $$(if $$(filter inkscape,$$(bml.autosvg.pdfconverter)),INKSCAPEFLAGS, \
      $$(if $$(filter mutool,$$(bml.autosvg.pdfconverter)),MUTOOLFLAGS, \
        $$(if $$(filter pdftocairo,$$(bml.autosvg.pdfconverter)),PDFTOCAIROFLAGS,DVISVGMFLAGS INKSCAPEFLAGS MUTOOLFLAGS PDFTOCAIROFLAGS)))),,pdf)

# match EPS first, as dvisvgm is more reliable with it
bmlimages/svg/%.svg: %.eps $(BOOKML_DEPS_AUTOSVG) $$(call bml.config.prereq,epstosvg) \
  | $$(@D)/./ $(call bml.config.predir,epstosvg)
	@$(bml.autosvg.recipe)
bmlimages/svg/%.svg: %.EPS $(BOOKML_DEPS_AUTOSVG) $$(call bml.config.prereq,epstosvg) \
  | $$(@D)/./ $(call bml.config.predir,epstosvg)
	@$(bml.autosvg.recipe)
bmlimages/svg/%.svg: %.pdf $(BOOKML_DEPS_AUTOSVG) $$(call bml.config.prereq,pdftosvg) \
  | $$(@D)/./ $(call bml.config.predir,pdftosvg)
	@$(bml.autosvg.recipe)
bmlimages/svg/%.svg: %.PDF $(BOOKML_DEPS_AUTOSVG) $$(call bml.config.prereq,pdftosvg) \
  | $$(@D)/./ $(call bml.config.predir,pdftosvg)
	@$(bml.autosvg.recipe)

# additional recipes for targets with custom page numbers or source not of the form %.pdf, %.eps
ifdef bml.autosvg.eps
$(sort $(bml.autosvg.eps)): bmlimages/svg/%.svg: $(BOOKML_DEPS_AUTOSVG) $$(call bml.config.prereq,epstosvg) \
  | $$(@D)/./ $(call bml.config.predir,epstosvg)
	@$(bml.autosvg.recipe)
endif
ifdef bml.autosvg.pdf
$(sort $(bml.autosvg.pdf)): bmlimages/svg/%.svg: $(BOOKML_DEPS_AUTOSVG) $$(call bml.config.prereq,pdftosvg) \
  | $$(@D)/./ $(call bml.config.predir,pdftosvg)
	@$(bml.autosvg.recipe)
endif

### SCORM AND ZIP
# SCORM must come first as GNU Make 3.81 picks the first matching pattern rule

# minimal manifest (a list of files generated by latexmlpost in XML format)
# it must be refreshed whenever any content has been modified, including the
# folders (e.g. if a file has been deleted)
$(AUX_DIR)/latexmlaux/%.manifest: $(AUX_DIR)/html/%/index.html $(BOOKML_DEPS_MANIFEST) $$(call bml.htmltree.for,$$*)
	@$(call bml.print.cmd,$(PERL) bookml/manifest.pl $(call bml.utils.escape2args,$(AUX_DIR)/html/$*,$@))

# SCORM manifest
$(AUX_DIR)/scorm/%/imsmanifest.xml: $(AUX_DIR)/latexmlaux/%.manifest $(BOOKML_DEPS_IMSMANIFEST) | $$(@D)/./
	@$(call bml.print.recipe,SCORM manifest,$*.xml,$(AUX_DIR)/scorm/$*/imsmanifest.xml)
	@$(call bml.print.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-imsmanifest.xsl \
	  --stringparam BML_MANIFEST $(call bml.utils.escape3args,../latexmlaux/$*.manifest,$(AUX_DIR)/xml/$*.xml,--output=$@))

# SCORM zip
$(AUX_DIR)/scorm/SCORM.%.zip: $(AUX_DIR)/scorm/%/imsmanifest.xml | $$(@D)/./
	@$(call bml.print.recipe,SCORM,$(AUX_DIR)/html/$*,SCORM.$*.zip)
	@$(call bml.utils.rm,$@)
	@$(call bml.print.cmd,cd $(call bml.utils.escapearg,$(call bml.utils.ospath,$(AUX_DIR)/html/$*))) $(bml.utils.;) $(call bml.print.cmd,$(ZIP) --quiet --recurse-paths $(call bml.utils.escapearg,$(call bml.utils.ospath,../../scorm/SCORM.$*.zip)) .)
	@$(call bml.print.cmd,cd $(call bml.utils.escapearg,$(call bml.utils.ospath,$(AUX_DIR)/scorm/$*))) $(bml.utils.;) $(call bml.print.cmd,$(ZIP) --quiet --recurse-paths $(call bml.utils.escapearg,$(call bml.utils.ospath,../SCORM.$*.zip)) .)

# zip
# it must be refreshed whenever any content has been modified, including the
# folders (e.g. if a file has been deleted)
$(AUX_DIR)/zip/%.zip: $(AUX_DIR)/html/%/index.html $$(call bml.htmltree.for,$$*) | $$(@D)/./
	@$(call bml.print.recipe,zip,$(AUX_DIR)/html/$*,$*.zip)
	@$(call bml.utils.rm,$@)
	@$(call bml.print.cmd,cd $(call bml.utils.escapearg,$(call bml.utils.ospath,$(AUX_DIR)/html))) $(bml.utils.;) $(call bml.print.cmd,$(ZIP) --quiet --recurse-paths $(call bml.utils.escape2args,$(call bml.utils.ospath,../zip/$*.zip),$*))

### COPY FROM $(AUX_DIR) TO WORKING DIRECTORY
# use second expansion to force matching $(AUX_DIR)/pdf/$*.pdf instead of
# $(*D)/$(AUX_DIR)/pdf/$(*F).pdf

# prevent files from outside the current directory or within $(AUX_DIR) from matching
bml.assertcurdir = $(if $(filter $(AUX_DIR)/% /,$(call bml.utils.relpath,$@)/),$(AUX_DIR)/NON_EXISTENT_TARGET)

%.pdf: $$(AUX_DIR)/pdf/$$(call bml.utils.relpath,$$@) $$(bml.assertcurdir)
	@$(call bml.print.cmd,$(CP) $(call bml.utils.escape2args,$(call bml.utils.ospath,$<),$(call bml.utils.ospath,$@)))
	@$(call bml.utils.cp,$(AUX_DIR)/pdf/$*.synctex.gz,$*.synctex.gz)
	@$(call bml.utils.cp,$(AUX_DIR)/pdf/$*.synctex,$*.synctex)

SCORM.%.zip: $$(AUX_DIR)/scorm/$$(call bml.utils.relpath,$$@) $$(bml.assertcurdir)
	@$(call bml.print.cmd,$(CP) $(call bml.utils.escape2args,$(call bml.utils.ospath,$<),$(call bml.utils.ospath,$@)))

%.zip: $$(AUX_DIR)/zip/$$(call bml.utils.relpath,$$@) $$(bml.assertcurdir)
	@$(call bml.print.cmd,$(CP) $(call bml.utils.escape2args,$(call bml.utils.ospath,$<),$(call bml.utils.ospath,$@)))
