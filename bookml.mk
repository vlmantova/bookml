# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-25  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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

bml.is.win := $(if $(subst xWindows_NT,,x$(OS)),,true)
# find if a command is available
ifeq ($(bml.is.win),true)
  bml.which = $(shell where "$1" 2>NUL)
else
  bml.which = $(shell command -v "$1")
endif
# backward compatible file/grep function
ifeq ($(findstring version-3.8,version-$(MAKE_VERSION)),version-3.8)
  ifeq ($(bml.is.win),true)
    bml.file = $(shell type $(subst /,\,$1))
  else
    bml.file = $(shell cat -- $1)
  endif
else
  bml.file = $(file < $1)
endif
bml.grep = $(findstring $1,$(call bml.file,$2))

### CONFIGURATION
# Configure these variables inside 'Makefile' before 'include bookml/bookml.mk'
# (1) where to store auxiliary files (*.aux, *.d, *.toc,...)
AUX_DIR ?= auxdir
export AUX_DIR
# (2) latexmk command and options
LATEXMK      ?= latexmk
LATEXMKFLAGS ?=
SYNCTEX      ?= 5 # must produce *.synctex.gz
# (3) latexml commands and options
LATEXML          ?= latexml
LATEXMLPOST      ?= latexmlpost
LATEXMLFLAGS     ?=
LATEXMLPOSTFLAGS ?=
# (4) perl command
PERL ?= perl
# (5) how to split into multiple files (section, chapter, etc), set to empty string to disable splitting
SPLITAT ?= section
# (6) source files: by default, all .tex files containing a \documentclass, unless this is a recursive call
ifndef SOURCES
  ifndef BMLGOALS
	  bml.allsources := $(wildcard *.tex)
    $(if $(filter-out %.tex,$(bml.allsources)),$(warning Some .tex files have spaces in their names, which is not supported!))
    SOURCES := $(sort $(foreach f,$(filter %.tex,$(bml.allsources)),$(if $(call bml.grep,\documentclass,$(f)),$(f))))
  endif
endif
# (7) formats: possible values are pdf, scorm, zip
FORMATS          ?= scorm zip
FORMATS.CMD      := $(filter pdf scorm zip,$(MAKECMDGOALS))
override FORMATS := $(sort $(FORMATS) $(FORMATS.CMD))
# (8) files to be built: by default, a .zip and a SCORM.zip file for each .tex file in $(SOURCES)
TARGETS.PDF   ?= $(sort $(SOURCES:.tex=.pdf))
TARGETS.XML   ?= $(patsubst %.tex,$(AUX_DIR)/xml/%.xml,$(sort $(SOURCES)))
TARGETS.HTML  ?= $(patsubst $(AUX_DIR)/xml/%.xml,$(AUX_DIR)/html/%/index.html,$(TARGETS.XML))
TARGETS.ZIP   ?= $(patsubst $(AUX_DIR)/html/%/index.html,%.zip,$(TARGETS.HTML))
TARGETS.SCORM ?= $(patsubst $(AUX_DIR)/html/%/index.html,SCORM.%.zip,$(TARGETS.HTML))
TARGETS.CMD   := $(filter-out all pdf scorm zip clean clean-% detect detect-%,$(MAKECMDGOALS))
TARGETS       ?= $(sort $(if $(filter pdf,$(FORMATS)),$(TARGETS.PDF)) $(if $(filter zip,$(FORMATS)),$(TARGETS.ZIP)) $(if $(filter scorm,$(FORMATS)),$(TARGETS.SCORM)))
ifneq (,$(BMLGOALS))
override TARGETS = $(sort $(BMLGOALS))
endif
# (9) texfot (optional, disable with TEXFOT=)
ifndef TEXFOT
  TEXFOT    := $(if $(call bml.which,texfot),texfot)
endif
TEXFOTFLAGS ?= $(if $(TEXFOT),--no-stderr,)
# (10) various terminal commands: by default, use typical Windows or Unix version
ifeq ($(bml.is.win),true)
  ifndef ZIP
    ZIP        := $(if $(call bml.which,zip),zip,miktex-zip)
  endif
  ifndef UNZIP
    UNZIP      := $(if $(call bml.which,tar),tar)
    UNZIPFLAGS := -x -f
  endif
  CP           := copy
  RMDIR        := rd /s /q
  RM           := del /f /s /q
  MKDIR        := mkdir
else
  ZIP          ?= zip
  ifndef UNZIP
    UNZIP      := $(if $(call bml.which,unzip),unzip)
    UNZIPFLAGS := -o
  endif
  CP           := cp
  RMDIR        := rm -fr --
  RM           := rm -f --
  MKDIR        := mkdir -p --
endif
ZIP_EXCLUDE ?= -x
ifndef CURL
  CURL := $(if $(call bml.which,curl),curl)
endif
# (11) dvisvgm
DVISVGM      ?= dvisvgm
DVISVGMFLAGS ?= --no-fonts --optimize
# (12) mutool
MUTOOL      ?= mutool
MUTOOLFLAGS ?=
# (13) choice of PDF to SVG converter
PDFTOSVG_CONVERTER ?= $(if $(MUTOOL),mutool,$(if $(DVISVGM),dvisvgm))
### END CONFIGURATION

### INTERNAL VARIABLES
BOOKML_DEPS_PDF         = bookml/latexmk.rc
BOOKML_DEPS_HTML        = $(wildcard LaTeXML-html5.xsl bookml/XSLT/*.xsl bookml/search_index.pl bookml/XSLT/proc-text.xsl)
BOOKML_DEPS_XML         = bookml/XSLT/proc-preprocess-xml.xsl bookml/XSLT/utils.xsl bookml/xsltproc.pl
BOOKML_DEPS_IMSMANIFEST = bookml/XSLT/proc-imsmanifest.xsl bookml/xsltproc.pl
BOOKML_DEPS_HTMLDEPS    = bookml/XSLT/proc-resources.xsl bookml/XSLT/utils.xsl bookml/xsltproc.pl
BOOKML_DEPS_AUTOSVG     = bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl bookml/XSLT/utils.xsl

### default target
all:
	@$(if $(SOURCES),,$(call bml.echo,$(bml.red) Warning: no .tex files with \documentclass found in this directory))
.PHONY: all

### determine which files need to be compiled
MAKECMDGOALS ?= $(.DEFAULT_GOAL)
BMLGOALS += \
  $(if $(filter all,  $(MAKECMDGOALS)),$(TARGETS)) \
  $(if $(filter html, $(MAKECMDGOALS)),$(TARGETS.HTML)) \
  $(if $(filter pdf,  $(MAKECMDGOALS)),$(patsubst %,$(AUX_DIR)/pdf/%,$(join $(TARGETS.PDF:=/),$(notdir $(TARGETS.PDF))))) \
  $(if $(filter scorm,$(MAKECMDGOALS)),$(TARGETS.SCORM)) \
  $(if $(filter xml,  $(MAKECMDGOALS)),$(TARGETS.XML)) \
  $(if $(filter zip,  $(MAKECMDGOALS)),$(TARGETS.ZIP)) \
  $(filter-out all html pdf scorm xml zip,$(MAKECMDGOALS))

ifneq ($(filter clean-%,$(MAKECMDGOALS))$(filter clean,$(MAKECMDGOALS)),)
BMLGOALS =
endif

bml.extract.jobname = $(foreach pat,$1,$(patsubst $(pat),%,$(filter $(pat),$2)))

bmljobs.scorm  += $(call bml.extract.jobname,SCORM.%.zip,$(BMLGOALS))
bmljobs.zip    += $(call bml.extract.jobname,%.zip,$(filter-out SCORM.%.zip,$(BMLGOALS)))
bmljobs.html   += $(bmljobs.SCORM) $(bmljobs.zip) \
  $(call bml.extract.jobname,$(AUX_DIR)/html/%/index.html,$(BMLGOALS)) 
bmljobs.xml    += $(bmljobs.html) \
  $(call bml.extract.jobname,$(AUX_DIR)/xml/%.xml $(AUX_DIR)/latexmlaux/%.logdeps $(AUX_DIR)/deps/%.htmldeps,$(BMLGOALS))
bmljobs.pdf    += $(call bml.extract.jobname,%.pdf/,$(dir \
  $(call bml.extract.jobname,$(addprefix $(AUX_DIR)/pdf/%,.pdf .aux .fls .logdeps),$(BMLGOALS)))) \
  $(call bml.extract.jobname,%.pdf $(AUX_DIR)/deps/%.pdfdeps,$(filter-out $(AUX_DIR)/pdf/%,$(BMLGOALS)))
bmljobs.pdfaux += \
  $(call bml.extract.jobname,$(addprefix $(AUX_DIR)/pdfaux/%,.aux .logdeps) $(AUX_DIR)/deps/%.pdfauxdeps,$(BMLGOALS))

# include all deps files
# to avoid rebuilding everything, we only instruct make on how to rebuild the ones we are sure will be used

bml.knowndeps = $(filter $(AUX_DIR)/deps/%.$1deps,$(BMLGOALS)) $(patsubst %,$(AUX_DIR)/deps/%.$1deps,$(bmljobs.$1))
bml.alldeps   = $(sort $(bml.deps.$1) $(wildcard $(AUX_DIR)/deps/*.$1deps))

bml.deps.html += $(call bml.knowndeps,html)
-include $(call bml.alldeps,html)

bml.deps.xml += $(call bml.knowndeps,xml)
-include $(call bml.alldeps,xml)

bml.deps.pdf += $(call bml.knowndeps,pdf)
-include $(call bml.alldeps,pdf)

bml.deps.pdfaux += $(call bml.knowndeps,pdfaux)
-include $(call bml.alldeps,pdfaux)

# direct: when the deps file is automatically rebuilt before evaluation; the deps file is missing, FORCE the build as we cannot detect if it is out of date
# recurse: use Make recursion to trigger recompilation and reevaluation of the deps file (last resort!)
bml.direct  = $(if $(filter $(AUX_DIR)/deps/$*.$1deps,$(bml.deps.$1)),$(if $(wildcard $(AUX_DIR)/deps/$*.$1deps),,FORCE),$(AUX_DIR)/NONEXISTENT_INVALID_TARGET)
bml.recurse = $(if $(filter $(AUX_DIR)/deps/$*.$1deps,$(bml.deps.$1)),$(AUX_DIR)/NONEXISTENT_INVALID_TARGET)

bml.direct.pdf  = $(if $(filter $(AUX_DIR)/deps/$(basename $(*D)).pdfdeps,$(bml.deps.pdf)),$(if $(wildcard $(AUX_DIR)/deps/$(basename $(*D)).pdfdeps),,FORCE),$(AUX_DIR)/NONEXISTENT_INVALID_TARGET)
bml.recurse.pdf = $(if $(filter $(AUX_DIR)/deps/$(basename $(*D)).pdfdeps,$(bml.deps.pdf)),$(AUX_DIR)/NONEXISTENT_INVALID_TARGET)

# treat the target as 'not intermediate': if the file is missing, it must be rebuilt
bml.not.intermediate = $(if $(wildcard $@),,FORCE)

### UTILS
# per-target configuration variables
bml.tovarprefix = $(subst /,_,$(subst #,_,$(subst -,_,$(subst =,_,$(subst +,_,$1)))))
bml.getvar      = $(if $(filter undefined,$(origin $(call bml.tovarprefix,$1)_$2)),$($2),$($(call bml.tovarprefix,$1)_$2))
bml.var         = $(call bml.getvar,$*,$1)
bml.getflags    = $($2) $($(call bml.tovarprefix,$1)_$2)
bml.flags       = $(call bml.getflags,$*,$1)

# cross-platform convenience variables
bml.openp   := (
bml.closedp := )
bml.comma   := ,
define bml.nl # newline


endef

# recursively list all files and folders, or just files, within a directory (after https://stackoverflow.com/a/18258352)
bml.reclist      = $(foreach d,$(wildcard $(1:=/*)),$(call bml.reclist,$d) $d)
# list leaf folders only to speed up folder creation
bml.reclist.dir  = $(foreach d,$(wildcard $(1:=/*/./)),$(eval _x:=$(call bml.reclist.dir,$(d:/./=)))$(if $(_x),$(_x),$(d:/./=)))
bml.reclist.file = $(foreach d,$(wildcard $(1:=/*)),$(eval _x:=$(call bml.reclist.file,$d))$(if $(_x),$(_x),$d)) # BUG: empty folders are interpreted as files

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

# progress output (code inspired by GMSL)
bml.spc := $(strip) $(strip)
bml.box  = $(call bml.echo,$(bml.redbg)$(bml.white) $(strip $(subst $(bml.spc)$(bml.esc)[,$(bml.esc)[,$1))$(bml.reset)$(bml.redbg) )
ifeq ($(bml.is.win),true)
  bml.cmd  = $(call bml.echo,$(bml.cyan)$1) & $1
  bml.echo = echo $(subst >,^>,$1)$(bml.reset)
else
  bml.cmd  = $(call bml.echo,$(bml.cyan)$1)$(subst \,\\,$1)
  bml.echo = $(info $1$(bml.reset))
endif
bml.prog = $(call bml.box,$1)

# colors
ifeq ($(call ver.lt,$(MAKE_VERSION),4.1),true)
  MAKE_TERMOUT ?= $(if $(bml.is.win),,$(shell tput setaf 1 >/dev/null 2>&1 && echo true))
endif
ifneq (,$(MAKE_TERMOUT))
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
  ifeq ($(bml.is.win),true)
    __ignore    := $(shell chcp 65001)
  endif
endif

ifeq ($(bml.is.win),true)
  SHELL       := cmd.exe
  bml.ospath   = $(subst /,$(bml.pathsep),$1)
  bml.pathsep := $(strip \)
  bml.null    := 2>NUL
  bml.lt      := ^<
  bml.gt      := ^>
  bml;        := &
  bml.mkdir    = if not exist "$(call bml.ospath,$1/)" $(MKDIR) "$(call bml.ospath,$1/)"
  bml.rm       = if exist "$(call bml.ospath,$1)" $(RM) "$(call bml.ospath,$1)"
  bml.rmdir    = if exist "$(call bml.ospath,$1/)" $(RMDIR) "$(call bml.ospath,$1/)"
  bml.cp       = if exist "$(call bml.ospath,$1)" $(CP) "$(call bml.ospath,$1)" "$(call bml.ospath,$2)"
else
  SHELL       := bash
  bml.ospath   = $1
  bml.pathsep := /
  bml.null    := 2>/dev/null
  bml.lt      := "<"
  bml.gt      := ">"
  bml;        := ;
  bml.mkdir    = $(MKDIR) "$1/"
  bml.rm       = $(RM) "$1"
  bml.rmdir    = $(RMDIR) "$1"
  bml.cp       = [ ! -f "$1" ] || $(CP) "$1" "$2"
endif

# friendly message checking for minimum and recommended version number
bml.recver  = $(strip $(if $3, \
  $(if $(call ver.leq,$1,$3),$(if $(call ver.leq,$2,$3),$(bml.green) $3 OK$(bml.reset), \
    $(bml.yellow) $3; recommended $2 or later), \
    $(bml.red) $3; required at least $1$(if $2,; recommended $2 or later)), \
    $(bml.red) NOT FOUND))
bml.testver = $(call bml.echo,$(bml.cyan)$1:$(call bml.recver,$2,$3,$4)$(bml.reset)$5)

# PDF to SVG conversion
ifeq ($(PDFTOSVG_CONVERTER),dvisvgm)
  ifeq ($(DVISVGM),)
    $(warning Option PDFTOSVG_CONVERTER is 'dvisvgm', but DVISVGM is empty. PDF figures will not be automatically converted to SVG.)
    PDFTOSVG_CONVERTER=
  else
    bml.pdftosvg=$(call bml.cmd,$(DVISVGM) $(DVISVGMFLAGS) --pdf $(if $(bml.svg.page),--page=$(bml.svg.page) )"$<" --output="$@")
  endif
else ifeq ($(PDFTOSVG_CONVERTER),mutool)
  ifeq ($(DVISVGM),)
    $(warning Option PDFTOSVG_CONVERTER is 'mutool', but MUTOOL is empty. PDF figures will not be automatically converted to SVG.)
    PDFTOSVG_CONVERTER=
  else
    # mutool always add the page number to the file name
    bml.pdftosvg=$(call bml.cmd,$(MUTOOL) draw $(MUTOOLFLAGS) -F svg "$<" $(if $(bml.svg.page),$(bml.svg.page),1) > $(call bml.ospath,"$@"))
  endif
else ifneq ($(PDFTOSVG_CONVERTER),)
$(warning Option PDFTOSVG_CONVERTER: value '$(PDFTOSVG_CONVERTER)' not recognised. PDF figures will not be automatically converted to SVG.)
PDFTOSVG_CONVERTER=
endif

ifneq ($(PDFTOSVG_CONVERTER),)
bml.pdftosvg.proc=$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl "$@" --output "$@")
endif

# do not delete intermediate files
.SECONDARY:

# enable second expansion for $$(...) dependencies
.SECONDEXPANSION:

# delete files on error
.DELETE_ON_ERROR:

# force recompilation
.PHONY: FORCE

all:
html:  TARGETS=$(TARGETS.HTML)
pdf:   TARGETS=$(TARGETS.PDF)
scorm: TARGETS=$(TARGETS.SCORM)
xml:   TARGETS=$(TARGETS.XML)
zip:   TARGETS=$(TARGETS.ZIP)

$(info $(bml.redbg)$(bml.white) $(strip $(subst $(bml.spc)$(bml.esc)[,$(bml.esc)[,Targets: $(sort $(TARGETS))$(if $(MAKE_RESTARTS), (further pass $(MAKE_RESTARTS)))$(if $(filter 0,$(MAKELEVEL)),, (recursion level $(MAKELEVEL))))) $(bml.reset))

all html pdf scorm xml zip: $$(TARGETS)
.PHONY: all html pdf scorm xml zip

# cleanup targets
clean:  clean-aux clean-html clean-pdf clean-scorm clean-svg clean-xml clean-zip
.PHONY: clean
.PHONY: clean-aux clean-html clean-pdf clean-scorm clean-svg clean-xml clean-zip

clean-aux:
	$(call bml.rmdir,$(AUX_DIR))
clean-html:
	-$(RM) $(call bml.ospath,$(AUX_DIR)/latexmlaux/*.LaTeXML.db $(AUX_DIR)/latexmlaux/*.latexmlpost.log)
	$(call bml.rmdir,$(AUX_DIR)/html)
clean-pdf:
	-$(call bml.rmdir,$(AUX_DIR)/pdf)
	-$(call bml.rmdir,$(AUX_DIR)/pdfaux)
	-$(RM) $(call bml.ospath,$(TARGETS.PDF) $(TARGETS.PDF:.pdf=.synctex) $(TARGETS.PDF:.pdf=.synctex.gz))
clean-scorm:
	-$(call bml.rmdir,$(AUX_DIR)/scorm)
	-$(RM) $(call bml.ospath,$(TARGETS.SCORM))
clean-svg:
	$(call bml.rmdir,bmlimages/svg)
clean-xml:
	-$(call bml.rmdir,$(AUX_DIR)/xml)
	-$(call bml.rmdir,bmlimages/dvi)
	-$(RM) $(call bml.ospath,$(AUX_DIR)/latexmlaux/*.latexml.log $(AUX_DIR)/latexmlaux/*.latexml.logdeps)
	-$(RM) $(call bml.ospath,$(patsubst $(AUX_DIR)/xml/%.xml,bmlimages/%-*.svg,$(TARGETS.XML)))
clean-zip:
	$(call bml.rmdir,$(AUX_DIR)/zip)
	-$(RM) $(call bml.ospath,$(TARGETS.ZIP))

# check for updates
.PHONY: check-for-update update
# if running from a Docker image
ifdef BOOKML_VERSION
check-for-update:
	@$(if $(call ver.lt,@VERSION@,$(BOOKML_VERSION)),$(call bml.echo,$(bml.yellow)BookML update $(BOOKML_VERSION) available$(bml.comma) run `$(MAKE) update` to install it.))
	@:
update:
	@$(call bml.echo,$(bml.yellow)Replacing BookML @VERSION@ with $(BOOKML_VERSION).)
	@$(call bml.cmd,$(UNZIP) $(UNZIPFLAGS) /release.zip)
else
check-for-update:
	@$(if $(CURL),,$(call bml.echo,$(bml.red)Checking for updates requires curl, aborting. Visit https://github.com/vlmantova/bookml/releases to find the latest release.)exit 1)
	@$(eval bookml_release:=$(if $(CURL),$(shell $(CURL) -s https://api.github.com/repos/vlmantova/bookml/releases/latest)))
	@$(eval bookml_version:=$(if $(CURL),$(word 3,$(subst ", ,$(filter "tag_name":_%,$(subst "tag_name": ,"tag_name":_,$(bookml_release)))))))
	@$(if $(CURL),$(call bml.echo,$(bml.yellow)$(if $(call ver.lt,@VERSION@,$(bookml_version)),BookML $(bookml_version) is newer than @VERSION@. Run `$(MAKE) update` to install it.,BookML @VERSION@ is already up to date.)))
	@:

update: | $(AUX_DIR)
	@$(if $(CURL),,$(call bml.echo,$(bml.red)Updating requires curl, aborting. Visit https://github.com/vlmantova/bookml/releases to find the latest release.)exit 1)
	@$(if $(CURL),$(if $(UNZIP),,$(call bml.echo,$(bml.red)Updating requires $(if $(bml.is.win),tar.exe,unzip), aborting.)exit 1))
	@$(eval bookml_release:=$(if $(CURL),$(if $(UNZIP),$(shell $(CURL) -s https://api.github.com/repos/vlmantova/bookml/releases/latest))))
	@$(eval bookml_version:=$(if $(CURL),$(if $(UNZIP),$(word 3,$(subst ", ,$(filter "tag_name":_%,$(subst "tag_name": ,"tag_name":_,$(bookml_release))))))))
	@$(eval bookml_update:=$(if $(CURL),$(if $(UNZIP),$(call ver.lt,@VERSION@,$(bookml_version)))))
	@$(if $(bookml_update),$(call bml.echo,$(bml.yellow)BookML $(bookml_version) is newer than @VERSION@$(bml.comma) updating.,BookML @VERSION@ is already up to date.))
	@$(if $(bookml_update),$(call bml.cmd,$(CURL) -L https://github.com/vlmantova/bookml/releases/download/$(bookml_version)/release.zip -o "$(AUX_DIR)/release.zip"))
	@$(if $(bookml_update),$(call bml.cmd,$(UNZIP) $(UNZIPFLAGS) "$(AUX_DIR)/release.zip"))
endif

# dump auxdir into zip file
.PHONY: aux-zip
aux-zip: | $(AUX_DIR)
	@$(call bml.rm,AUX.$(AUX_DIR).zip)
	@$(call bml.cmd,$(ZIP) --quiet --recurse-paths "AUX.$(AUX_DIR).zip" "$(AUX_DIR)")

# version detection targets
detect: DETECT_CORE:=detect-core
detect: DETECT_IMAGE:=detect-image
detect: DETECT_BMLIMAGE:=detect-bmlimage
detect: detect-core detect-image detect-bmlimage detect-misc
	@:
.PHONY: detect-sources detect-bookml detect-make detect-tex detect-perl \
  detect-latexml detect-imagemagick detect-ghostscript detect-mutool \
  detect-dvisvgm detect-latexmk detect-texfot detect-preview detect-zip \
  detect-curl detect detect-core detect-image detect-bmlimage detect-misc \
  announce-detect-core announce-detect-image announce-detect-bmlimage \
  announce-detect-misc detect-pdftosvg-converter

announce-detect-core:
	@$(call bml.box,     Required                                                                 )
	@:
detect-core: detect-sources detect-bookml detect-make detect-tex detect-perl detect-latexml detect-latexmk detect-zip
	@:
detect-sources: announce-detect-core
	@$(call bml.echo,$(bml.cyan)    Main files:$(if $(SOURCES) \
	  ,$(bml.green) $(SOURCES),$(bml.red) no .tex files with \documentclass found in this directory))
	@:
detect-bookml: announce-detect-core
	@$(call bml.testver,        BookML,,,@VERSION@)
	@:
detect-tex: announce-detect-core
	@$(eval tex_ver:=$(subst  , ,$(patsubst $(bml.openp)%,%,$(filter $(bml.openp)%,$(subst $(bml.closedp), , \
	  $(subst $(bml.openp), $(bml.openp),$(subst $(bml.spc), ,$(shell tex -version $(bml.null)))))))))
	@$(call bml.testver,           TeX,,,$(tex_ver))
	@:
detect-make: announce-detect-core
	@$(call bml.testver,      GNU Make,3.81,4.3,$(MAKE_VERSION))
	@:
detect-perl: announce-detect-core
	@$(eval perl_ver:=$(subst $(bml.closedp),,$(subst $(bml.openp),,$(firstword \
	  $(filter $(bml.openp)%,$(shell perl --version $(bml.null)))))))
	@$(call bml.testver,          perl,5.8.1,,$(perl_ver),)
	@:
detect-latexml: announce-detect-core
	@$(eval latexml_ver:=$(subst $(bml.closedp),,$(filter %$(bml.closedp), \
	  $(shell $(LATEXML) --VERSION 2>&1))))
	@$(call bml.testver,       LaTeXML,0.8.7,0.8.8,$(latexml_ver))
	@:
detect-latexmk: announce-detect-core
	@$(call bml.testver,       latexmk,,,$(lastword $(shell $(LATEXMK) --version $(bml.null))))
	@:
detect-zip: announce-detect-core
	@$(eval zip_ver := $(firstword $(subst Zip_,,\
	  $(filter Zip_%,$(subst Zip ,Zip_,$(shell $(ZIP) -v $(bml.null)))))))
	@$(call bml.testver,           zip,,,$(zip_ver))
	@:

announce-detect-image: $$(DETECT_CORE)
	@$(call bml.box,     Optional: for any image handling$(bml.comma) including BookML images                )
	@:
detect-image: detect-imagemagick detect-ghostscript detect-mutool detect-dvisvgm
	@:
detect-imagemagick: announce-detect-image
	@$(foreach a,Magick Magick::Q16 Magick::Q16HDRI Magick::Q8, \
	  $(if $(magick_ver),,$(eval magick_ver:=$(shell perl -MImage::$a -e "print Image::$a->VERSION" $(bml.null)))))
	@$(call bml.testver, Image::Magick,,,$(magick_ver))
	@:
detect-pdftosvg-converter: announce-detect-image
	@$(call bml.echo,$(bml.magenta) --- PDFTOSVG_CONVERTER is set to '$(PDFTOSVG_CONVERTER)' ---)
	@:
detect-ghostscript: announce-detect-image detect-pdftosvg-converter
	@$(foreach a, \
	  $(if $(bml.is.win),gswin64c gswin64 gswin32c gswin32 mgs,gs), \
	  $(if $(gs_info),,$(eval gs_info:=$(shell $a -v $(bml.null)))))
	@$(eval gs_ver:=$(firstword $(subst Ghostscript_,,$(filter Ghostscript_%,$(subst Ghostscript ,Ghostscript_,$(gs_info))))))
	@$(eval gs_ver:=$(firstword $(subst Ghostscript_,,$(filter Ghostscript_%,$(subst Ghostscript ,Ghostscript_,$(gs_info))))))
	@$(call bml.testver,   Ghostscript,,,$(gs_ver), (BookML images, EPS to SVG, PDF to SVG via dvisvgm))
	@:
detect-dvisvgm: announce-detect-image detect-pdftosvg-converter
	@$(eval dvisvgm_info:=$(if $(DVISVGM),$(shell $(DVISVGM) -V1 $(bml.null))))
	@$(eval dvisvgm_ver:=$(firstword $(subst dvisvgm_,,$(filter dvisvgm_%,$(subst $(DVISVGM) ,dvisvgm_,$(dvisvgm_info))))))
	@$(eval gs_ver:=$(wordlist 2,2,$(subst &, ,$(filter Ghostscript:%,$(subst &Ghostscript:, Ghostscript:,$(subst $() ,&,$(dvisvgm_info)))))))
	@$(eval mutool_ver:=$(wordlist 2,2,$(subst &, ,$(filter mutool:%,$(subst &mutool:, mutool:,$(subst $() ,&,$(dvisvgm_info)))))))
	@$(eval needs_mutool:=$(if $(call ver.leq,10.01.0,$(gs_ver)),true))
	@$(call bml.testver,       dvisvgm,1.6,2.7,$(dvisvgm_ver), (BookML images, EPS to SVG$(if $(needs_mutool),,, PDF to SVG via dvisvgm)))
	@$(call bml.testver, dvisvgm/libgs,,,$(gs_ver), (BookML images, EPS to SVG$(if $(needs_mutool),,, PDF to SVG via dvisvgm)))
	@$(if $(needs_mutool),$(call bml.testver,       dvisvgm,3.0,,$(dvisvgm_ver), (PDF to SVG via dvisvgm)))
	@$(if $(needs_mutool),$(call bml.testver,dvisvgm/mutool,,,$(mutool_ver), (PDF to SVG via dvisvgm)))
	@:
detect-mutool: announce-detect-image detect-pdftosvg-converter
	@$(eval mutool_info:=$(shell $(MUTOOL) -v 2>&1))
	@$(eval mutool_ver:=$(if $(filter-out mutool,$(firstword $(mutool_info))),,$(lastword $(mutool_info))))
	@$(call bml.testver,        mutool,,,$(mutool_ver), (PDF to SVG via mutool))
	@:

announce-detect-bmlimage: $$(DETECT_CORE) detect-image
	@$(call bml.box,     Optional: BookML images (\bmlImageEnvironment and \begin{bmlimage})      )
	@:
detect-bmlimage: detect-preview
	@:
detect-preview: announce-detect-bmlimage
	@$(eval preview_loc:=$(shell kpsewhich preview.sty $(bml.null)))
	@$(eval preview_ver:=$(if $(preview_loc),$(subst },,$(subst _,., \
	  $(subst RELEASE_,, $(filter RELEASE_%,$(subst \def\pr@version{,RELEASE_,$(subst $$Name: release_,RELEASE_,$(call bml.file,$(preview_loc))))))))))
	@$(call bml.testver,   preview.sty,11.81,,$(preview_ver))
	@:
# } syntax highlighting gets confused by the open curly bracket!

announce-detect-misc: $$(DETECT_CORE) $$(DETECT_IMAGE) $$(DETECT_BMLIMAGE)
	@$(call bml.box,     Optional: misc                                                           )
	@:
detect-misc: detect-texfot detect-curl
	@:
detect-texfot: announce-detect-misc
	@$(call bml.testver,        texfot,,,$(wordlist 3,3,$(if $(TEXFOT),$(shell $(TEXFOT) --version $(bml.null)))), (hide irrelevant LaTeX messages))
	@:
detect-curl: announce-detect-misc
	@$(call bml.testver,          curl,,,$(wordlist 2,2,$(shell $(CURL) -V $(bml.null))), (update BookML with 'make update'))
	@:

# create directories
# for .pdf, remove existing .pdf files, to remain compatible with the previous builds
$(AUX_DIR)/pdf/%.pdf/./: | %.tex
	@$(call bml.rm,$(@:/./=))
	@$(call bml.mkdir,$@)

$(AUX_DIR)/%/./:
	$(call bml.mkdir,$@)

# copy PDF and synctex.gz files from $(AUX_DIR) to main folder
# use relative paths is possible (with extra work if there are spaces)
$(subst $(bml.spc),\ ,$(CURDIR))/%.pdf %.pdf: $(AUX_DIR)/pdf/$$*.pdf/$$(*F).pdf
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$*.pdf)")
	@$(call bml.cp,$(AUX_DIR)/pdf/$*.synctex.gz,$*.synctex.gz)
	@$(call bml.cp,$(AUX_DIR)/pdf/$*.synctex,$*.synctex)

# build PDF and deps files in $(AUX_DIR)

# generate all possible subfolders so that \include{subfolder/...} can write its aux files
bml.subtree := $(filter-out $(AUX_DIR)/% bmlimages/% bookml/%,$(patsubst ./%,%,$(call bml.reclist.dir,.)))
bml.auxdir.pdf.subtree = $(patsubst %,$(AUX_DIR)/pdf/$(*D)/%/./,$(bml.subtree))
bml.auxdir.pdfaux.subtree = $(patsubst %,$(AUX_DIR)/pdfaux/%/./,$(bml.subtree))

# typo LATEKMKFLAGS preserved for backwards compatibility
# build in subfolder AUX_DIR/pdf/jobname.pdf/jobname.pdf to isolate builds from each other
bml.assert.pdf.naming = $(if $(filter-out $(*F).pdf,$(notdir $(*D))),$(AUX_DIR)/NONEXISTENT_INVALID_TARGET)
$(AUX_DIR)/pdf/%.pdf $(AUX_DIR)/pdf/%.aux $(AUX_DIR)/pdf/%.fls $(AUX_DIR)/pdf/%.logdeps: $$(basename $$(*D)).tex $$(bml.assert.pdf.naming) $(BOOKML_DEPS_PDF) $$(bml.direct.pdf) $$(info pdf $$* -> $$(bml.direct.pdf)) | $$(@D)/./ $$(bml.auxdir.pdf.subtree)
	@$(call bml.prog,latexmk: $(basename $(*D)).tex → $(*D))
	@$(call bml.cmd,$(call bml.var,TEXFOT) $(call bml.flags,TEXFOTFLAGS) \
	  $(call bml.var,LATEXMK) -r bookml/latexmk.rc -pdf -dvi- -ps- \
	  $(if $(call bml.var,SYNCTEX),-synctex=$(call bml.var,SYNCTEX),) $(LATEKMKFLAGS) $(call bml.flags,LATEXMKFLAGS) \
	  -g -norc -interaction=nonstopmode -halt-on-error -file-line-error -recorder \
	  -MP -output-directory="$(@D)" "$<")
	@$(CP) "$(call bml.ospath,$(AUX_DIR)/pdf/$*.log)" "$(call bml.ospath,$(AUX_DIR)/pdf/$*.logdeps)"

$(AUX_DIR)/pdf/%.pdf $(AUX_DIR)/pdf/%.aux $(AUX_DIR)/pdf/%.fls $(AUX_DIR)/pdf/%.logdeps: $$(basename $$(*D)).tex $$(bml.assert.pdf.naming) $$(bml.recurse.pdf) $$(info pdf recursive $$* -> $$(bml.recurse.pdf))
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$(AUX_DIR)/pdf/$*.pdf"

$(sort $(bml.deps.pdf)): $(AUX_DIR)/deps/%.pdfdeps: $(AUX_DIR)/pdf/$$*.pdf/$$*.fls $(AUX_DIR)/pdf/$$*.pdf/$$*.logdeps bookml/deps.pl | $$(@D)/./
	@$(PERL) bookml/deps.pl -a "$(AUX_DIR)" -o "$@" "$(AUX_DIR)/pdf/$*.pdf/$*.fls" "$(AUX_DIR)/pdf/$*.pdf/$*.logdeps"

# if .tex invokes xr, compile its aux files separately to prevent cyclic dependencies
$(AUX_DIR)/pdfaux/%.aux $(AUX_DIR)/pdfaux/%.fls $(AUX_DIR)/pdfaux/%.logdeps: %.tex $$(call bml.direct,pdfaux) | $$(@D)/./ $(bml.auxdir.pdfaux.subtree)
	@$(call bml.prog,latexmk: $*.tex → pdfaux/$*.aux)
	@$(call bml.cmd,$(call bml.var,TEXFOT) $(call bml.flags,TEXFOTFLAGS) \
	  $(call bml.var,LATEXMK) -pdf -dvi- -ps- \
	  $(if $(call bml.var,SYNCTEX),-synctex=$(call bml.var,SYNCTEX),) $(LATEKMKFLAGS) $(call bml.flags,LATEXMKFLAGS) \
	  -g -norc -interaction=nonstopmode -halt-on-error -file-line-error -recorder \
	  -MP -output-directory="$(AUX_DIR)/pdfaux" "$<")
	@$(CP) "$(call bml.ospath,$(AUX_DIR)/pdfaux/$*.log)" "$(call bml.ospath,$(AUX_DIR)/pdfaux/$*.logdeps)"

$(AUX_DIR)/pdfaux/%.aux $(AUX_DIR)/pdfaux/%.fls $(AUX_DIR)/pdfaux/%.logdeps: %.tex $$(call bml.recurse,pdfaux)
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$(AUX_DIR)/pdf/$*.pdf"

$(sort $(bml.deps.pdfaux)): $(AUX_DIR)/deps/%.pdfauxdeps: $(AUX_DIR)/pdfaux/%.fls $(AUX_DIR)/pdfaux/%.logdeps bookml/deps.pl | $$(@D)/./
	@$(PERL) bookml/deps.pl -a "$(AUX_DIR)" -o "$@" "$(AUX_DIR)/pdfaux/$*.fls" "$(AUX_DIR)/pdfaux/$*.logdeps"

##### TODO:
# (2) deps.pl, proc-resources.xml: add .pdf prerequisites to BMLGOALS.PDF
# (7) determine how to set target-specific LATEXMKFLAGS so that they are picked up by all subtargets .pdf .aux .fls .logdeps and pdfaux/...

# build XML files
# (Windows can sometimes set the READONLY attribute on the xml folder,
#  especially on cloud drives, and this trips LaTeXML)
$(AUX_DIR)/xml/%.xml $(AUX_DIR)/latexmlaux/%.latexml.logdeps: %.tex $(BOOKML_DEPS_XML) $$(call bml.direct,xml) | $(AUX_DIR)/latexmlaux/./ $(AUX_DIR)/xml/./
	@$(call bml.prog,latexml: $< → $*.xml)
	@$(if $(bml.is.win),attrib -r "$(call bml.ospath,$(@D))")
	@$(call bml.cmd,$(LATEXML) --preamble=literal:\RequirePackage{bookml/bookml-init} \
	  $(LATEXMLFLAGS) $(LATEXMLEXTRAFLAGS) --log="$(AUX_DIR)/latexmlaux/$*.latexml.log" --destination="$(AUX_DIR)/xml/$*.xml" "$<")
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-preprocess-xml.xsl "$(AUX_DIR)/xml/$*.xml" --output "$(AUX_DIR)/xml/$*.xml" --stringparam AUX_DIR "$(AUX_DIR)" $(if $(PDFTOSVG_CONVERTER),,--stringparam AUTOSVG ""))
	@$(CP) "$(call bml.ospath,$(AUX_DIR)/latexmlaux/$*.latexml.log)" "$(call bml.ospath,$(AUX_DIR)/latexmlaux/$*.latexml.logdeps)"

$(AUX_DIR)/xml/%.xml $(AUX_DIR)/latexmlaux/%.latexml.logdeps: %.tex $$(call bml.recurse,xml)
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$(AUX_DIR)/xml/$*.xml"

$(sort $(bml.deps.xml)): $(AUX_DIR)/deps/%.xmldeps: $(AUX_DIR)/latexmlaux/%.latexml.logdeps bookml/deps.pl | $(AUX_DIR)/deps/./
	@$(PERL) bookml/deps.pl -a "$(AUX_DIR)" -o "$@" "$<"

# build HTML and deps files

# discover postprocessing dependencies (including bmluser/ files, alternative formats, images)
$(sort $(bml.deps.html)): $(AUX_DIR)/deps/%.htmldeps: $(AUX_DIR)/xml/%.xml $(BOOKML_DEPS_HTMLDEPS) | $(AUX_DIR)/deps/./
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-resources.xsl "$(AUX_DIR)/xml/$*.xml" --output "$@" --stringparam BML_TARGET "html/$*/index.html")

$(AUX_DIR)/html/%/index.html: $(AUX_DIR)/xml/%.xml $(BOOKML_DEPS_HTML) $$(call bml.direct,html) $$(info html $$* -> $$(call bml.direct,html))| $(AUX_DIR)/html/./
	@$(call bml.prog,latexmlpost: $*.xml → $(AUX_DIR)/html/$*/index.html)
	@$(call bml.rmdir,$(AUX_DIR)/html/$*)
	@$(call bml.cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  $(if $(SPLITAT),--splitat=$(SPLITAT)) --urlstyle=file --pmml --mathtex \
		$(LATEXMLPOSTFLAGS) $(LATEXMLPOSTEXTRAFLAGS) --xsltparameter=BMLSEARCH:yes --sourcedirectory=. $(LATEXMLPOSTAUTOFLAGS) \
	  --dbfile=$(AUX_DIR)/latexmlaux/"$*".LaTeXML.db --log="$(AUX_DIR)/latexmlaux/$*.latexmlpost.log" --destination="$@" "$<")
	@$(call bml.rm,$(AUX_DIR)/html/$*/LaTeXML.cache)
	@$(call bml.cmd,$(PERL) bookml/search_index.pl "$(AUX_DIR)/html/$*")

$(AUX_DIR)/html/%/index.html: $(AUX_DIR)/xml/%.xml $$(call bml.recurse,html) $$(info html recursive $$* -> $$(call bml.recurse,html))
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$@"

# copy zip and SCORM files from $(AUX_DIR) to main folder
$(subst $(bml.spc),\ ,$(CURDIR))/SCORM.%.zip SCORM.%.zip: $(AUX_DIR)/scorm/SCORM.%.zip
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$@)")
$(subst $(bml.spc),\ ,$(CURDIR))/%.zip %.zip: $(AUX_DIR)/zip/%.zip
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$@)")

# package HTML output and manifest into SCORM package
$(AUX_DIR)/scorm/SCORM.%.zip: $(AUX_DIR)/scorm/%/imsmanifest.xml
	@$(call bml.prog,SCORM: $(AUX_DIR)/html/$* → SCORM.$*.zip)
	@$(call bml.rm,$@)
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)html$(bml.pathsep)$*") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)..$(bml.pathsep)scorm$(bml.pathsep)SCORM.$*.zip" .)
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)scorm$(bml.pathsep)$*") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)SCORM.$*.zip" .)

# prevent make from trying to build the files in $(AUX_DIR)/html for which we have no recipe
$(foreach f,$(call bml.reclist.file,$(AUX_DIR)/html),$(eval $(f):))

# package HTML output into zip file
$(AUX_DIR)/zip/%.zip: $(AUX_DIR)/html/%/index.html $$(filter-out $$(AUX_DIR)/html/$$*/index.html,$$(call bml.reclist.file,$$(AUX_DIR)/html/$$*)) | $(AUX_DIR)/zip/./
	@$(call bml.prog,zip: $(AUX_DIR)/html/$* → $*.zip)
	@$(call bml.rm,$@)
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)html") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)zip$(bml.pathsep)$*.zip" "$*")

# create BookML minimal manifest (a list of files generated by latexmlpost in XML format)
$(AUX_DIR)/latexmlaux/%.manifest: $(AUX_DIR)/html/%/index.html bookml/manifest.pl $$(filter-out $$(AUX_DIR)/html/$$*/index.html,$$(call bml.reclist.file,$$(AUX_DIR)/html/$$*)) | $(AUX_DIR)/latexmlaux
	@$(call bml.cmd,$(PERL) bookml/manifest.pl "$(AUX_DIR)/html/$*" "$@")

# create SCORM manifest
$(AUX_DIR)/scorm/%/imsmanifest.xml: $(AUX_DIR)/latexmlaux/%.manifest $(BOOKML_DEPS_IMSMANIFEST) | $(AUX_DIR)/scorm/./
	@$(call bml.prog,SCORM manifest: $*.xml → $@)
	@$(call bml.mkdir,$(AUX_DIR)/scorm/$*)
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-imsmanifest.xsl "$(AUX_DIR)/xml/$*.xml" --output "$@" \
	   --stringparam BML_MANIFEST "../latexmlaux/$*.manifest")

# image conversions
# match EPS first, as dvisvgm is more reliable with it
bmlimages/svg/%.svg: $$(bml.svg.parent)%.eps $(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(call bml.cmd,$(DVISVGM) $(DVISVGMFLAGS) --eps "$<" --output="$@")
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl "$@" --output "$@")
bmlimages/svg/%.svg: $$(bml.svg.parent)%.EPS $(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(call bml.cmd,$(DVISVGM) $(DVISVGMFLAGS) --eps "$<" --output="$@")
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl "$@" --output "$@")

bmlimages/svg/%.svg: $$(bml.svg.parent)%.pdf $(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(bml.pdftosvg)
	@$(bml.pdftosvg.proc)
bmlimages/svg/%.svg: $$(bml.svg.parent)%.PDF $(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(bml.pdftosvg)
	@$(bml.pdftosvg.proc)

# /./ disambiguates between %.svg, %.pdf targets and actual folders
# a hack, but required to keep compatibility with GNU make 3.81
bmlimages/svg/%/./:
	@$(call bml.mkdir,$@)
bmlimages/svg/./:
	@$(call bml.mkdir,$@)
