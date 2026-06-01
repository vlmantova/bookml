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
    SOURCES := $(foreach f,$(filter %.tex,$(bml.allsources)),$(if $(call bml.grep,\documentclass,$(f)),$(f)))
  endif
endif
# (7) formats: possible values are pdf, scorm, zip
FORMATS ?= scorm zip
# (8) files to be built: by default, a .zip and a SCORM.zip file for each .tex file in $(SOURCES)
TARGETS.PDF   ?= $(SOURCES:.tex=.pdf)
TARGETS.XML   ?= $(patsubst %.pdf,$(AUX_DIR)/xml/%.xml,$(TARGETS.PDF))
TARGETS.HTML  ?= $(patsubst $(AUX_DIR)/xml/%.xml,$(AUX_DIR)/html/%/index.html,$(TARGETS.XML))
TARGETS.ZIP   ?= $(patsubst $(AUX_DIR)/html/%/index.html,%.zip,$(TARGETS.HTML))
TARGETS.SCORM ?= $(patsubst $(AUX_DIR)/html/%/index.html,SCORM.%.zip,$(TARGETS.HTML))
TARGETS       ?= $(if $(findstring pdf,$(FORMATS)),$(TARGETS.PDF)) $(if $(findstring zip,$(FORMATS)),$(TARGETS.ZIP)) $(if $(findstring scorm,$(FORMATS)),$(TARGETS.SCORM))
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
BOOKML_DEPS_HTML        = $(wildcard LaTeXML-html5.xsl bookml/XSLT/*.xsl bookml/search_index.pl bookml/XSLT/proc-text.xsl)
BOOKML_DEPS_XML         = $(wildcard bookml/*.ltxml bookml/*.rng) \
  bookml/XSLT/proc-svg.xsl bookml/XSLT/utils.xsl
BOOKML_DEPS_PREPROCESS  = bookml/XSLT/proc-preprocess-xml.xsl bookml/XSLT/utils.xsl bookml/xsltproc.pl
BOOKML_DEPS_IMSMANIFEST = bookml/XSLT/proc-imsmanifest.xsl bookml/xsltproc.pl
BOOKML_DEPS_HTMLDEPS    = bookml/XSLT/proc-resources.xsl bookml/XSLT/utils.xsl bookml/xsltproc.pl
BOOKML_DEPS_AUTOSVG     = bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl bookml/XSLT/utils.xsl


BMLGOALS ?= $(MAKECMDGOALS)

### UTILS
# cross-platform convenience variables
bml.openp   := (
bml.closedp := )
bml.comma   := ,
define bml.nl # newline


endef

# recursively list all files and folders, or just files, within a directory (after https://stackoverflow.com/a/18258352)
bml.reclist      = $(foreach d,$(wildcard $(1:=/*)),$(call bml.reclist,$d) $d)
bml.reclist.dir  = $(foreach d,$(wildcard $(1:=/*/./)),$(call bml.reclist.dir,$(d:/./=)) $(d:/./=))
bml.reclist.file = $(foreach d,$(wildcard $(1:=/*)),$(eval _x:=$(call bml.reclist.file,$d))$(if $(_x),$(_x),$d)) # BUG: empty folders are interpreted as files

# help editors detect UTF-8 encoding: ∀x.x=x

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
  bml.mkdir   = if not exist "$(call bml.ospath,$1/)" $(MKDIR) "$(call bml.ospath,$1/)"
  bml.rm      = if exist "$(call bml.ospath,$1)" $(RM) "$(call bml.ospath,$1)"
  bml.rmdir   = if exist "$(call bml.ospath,$1/)" $(RMDIR) "$(call bml.ospath,$1/)"
else
  SHELL      := bash
  bml.ospath  = $1
  bml.pathsep := /
  bml.null    := 2>/dev/null
  bml.lt      := "<"
  bml.gt      := ">"
  bml;        := ;
  bml.mkdir   = $(MKDIR) "$1/"
  bml.rm      = $(RM) "$1"
  bml.rmdir   = $(RMDIR) "$1"
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
    bml.pdftosvg=$(call bml.cmd,$(MUTOOL) draw $(MUTOOLFLAGS) -F svg "$<" $(bml.svg.page) > $(call bml.ospath,"$@"))
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

# default targets
all:
	@$(if $(SOURCES),,$(call bml.echo,$(bml.red) Warning: no .tex files with \documentclass found in this directory))
.PHONY: all

all:
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
clean:  clean-aux clean-html clean-pdf clean-scorm clean-svg clean-xml clean-zip
.PHONY: clean
.PHONY: clean-aux clean-html clean-pdf clean-scorm clean-svg clean-xml clean-zip

clean-aux:
	$(call bml.rmdir,$(AUX_DIR))
clean-html:
	-$(RM) $(call bml.ospath,$(AUX_DIR)/latexmlaux/*.LaTeXML.db $(AUX_DIR)/latexmlaux/*.latexmlpost.log)
	$(call bml.rmdir,$(AUX_DIR)/html)
clean-pdf:
	-$(RMDIR) $(call bml.ospath,$(AUX_DIR)/pdf)
	-$(RM) $(call bml.ospath,$(TARGETS.PDF) $(TARGETS.PDF:.pdf=.synctex) $(TARGETS.PDF:.pdf=.synctex.gz))
clean-scorm:
	-$(RM) $(call bml.ospath,$(TARGETS.SCORM))
clean-svg:
	$(call bml.rmdir,bmlimages/svg)
clean-xml:
	-$(RMDIR) $(call bml.ospath,$(AUX_DIR)/xml bmlimages/dvi)
	-$(RM) $(call bml.ospath,$(AUX_DIR)/latexmlaux/*.latexml.log)
	-$(RM) $(call bml.ospath,$(patsubst $(AUX_DIR)/xml/%.xml,bmlimages/%-*.svg,$(TARGETS.XML)))
clean-zip:
	-$(RM) $(call bml.ospath,$(TARGETS.ZIP))

# check for updates
.PHONY: check-for-update update
# if running from a Docker image
ifdef BOOKML_VERSION
check-for-update:
	@$(if $(call ver.lt,@VERSION@,$(BOOKML_VERSION)),$(call bml.echo,$(bml.yellow)BookML update $(BOOKML_VERSION) available$(bml.comma) run `update` to install it.))
update:
	@$(call bml.echo,$(bml.yellow)Replacing BookML @VERSION@ with $(BOOKML_VERSION).)
	@$(call bml.cmd,$(UNZIP) $(UNZIPFLAGS) /release.zip)
else
check-for-update:
	@$(if $(CURL),,$(call bml.echo,$(bml.red)Checking for updates requires curl, aborting. Visit https://github.com/vlmantova/bookml/releases to find the latest release.)exit 1)
	@$(eval bookml_release:=$(if $(CURL),$(shell $(CURL) -s https://api.github.com/repos/vlmantova/bookml/releases/latest)))
	@$(eval bookml_version:=$(if $(CURL),$(word 3,$(subst ", ,$(filter "tag_name":_%,$(subst "tag_name": ,"tag_name":_,$(bookml_release)))))))
	@$(if $(CURL),$(call bml.echo,$(bml.yellow)$(if $(call ver.lt,@VERSION@,$(bookml_version)),BookML $(bookml_version) is newer than @VERSION@. Run `update` to install it.,BookML @VERSION@ is already up to date.)))

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
$(patsubst %,$(AUX_DIR)/%,deps html latexmlaux pdf xml): | $(AUX_DIR)
$(AUX_DIR) $(patsubst %,$(AUX_DIR)/%,deps html latexmlaux pdf xml):
	@$(call bml.mkdir,$@)

# copy PDF and synctex.gz files from $(AUX_DIR) to main folder
# use relative paths is possible (with extra work if there are spaces)
$(subst $(bml.spc),\ ,$(CURDIR))/%.pdf %.pdf: $(AUX_DIR)/pdf/%.pdf
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$*.pdf)")
	-@$(CP) "$(call bml.ospath,$(AUX_DIR)/pdf/$*.synctex.gz)" "$(call bml.ospath,$*.synctex.gz)" $(bml.null)
	-@$(CP) "$(call bml.ospath,$(AUX_DIR)/pdf/$*.synctex)" "$(call bml.ospath,$*.synctex)" $(bml.null)

# build PDF and deps files (in $(AUX_DIR))

-include $(wildcard $(AUX_DIR)/deps/*.pdfdeps)

# force rebuild if pdfdeps file is missing
# typo LATEKMKFLAGS preserved for backwards compatibility
bml.auxdir.subtree := $(patsubst %,$(AUX_DIR)/pdf/%,$(filter-out $(AUX_DIR)/% bmlimages/% bookml/%,$(patsubst ./%,%,$(call bml.reclist.dir,.))))
$(AUX_DIR)/pdf/%.pdf: %.tex $$(if $$(wildcard $(AUX_DIR)/deps/$$*.pdfdeps),,FORCE) | $(AUX_DIR)/pdf $(AUX_DIR)/deps $(bml.auxdir.subtree)
	@$(call bml.prog,pdflatex: $*.tex → $*.pdf)
	@$(call bml.cmd,$(TEXFOT) $(TEXFOTFLAGS) $(LATEXMK) -pdf -dvi- -ps- $(if $(SYNCTEX),-synctex=$(SYNCTEX),) $(LATEKMKFLAGS) $(LATEXMKFLAGS) \
	  -g -norc -interaction=nonstopmode -halt-on-error -file-line-error -recorder \
	  -deps -deps-out="$(AUX_DIR)/deps/$*.pdfdeps" -MP -output-directory="$(AUX_DIR)/pdf" "$<")
	@$(PERL) -pi -e "if (s/^ +/\t/) { s/ /$(if $(bml.is.win),\\,\\\\) /g; s/^\t/    /; }" "$(AUX_DIR)/deps/$*.pdfdeps"

# mirror folder tree under $(AUX_DIR)/pdf to support including files from subfolders
$(bml.auxdir.subtree): $(AUX_DIR)/pdf/%:
	@$(call bml.mkdir,$@)

# build XML files
# (Windows can sometimes set the READONLY attribute on the xml folder,
#  especially on cloud drives, and this trips LaTeXML)
$(AUX_DIR)/xml/%.xml: %.tex $(BOOKML_DEPS_XML) $(wildcard *.ltxml) %.pdf | $(AUX_DIR)/latexmlaux $(AUX_DIR)/xml
	@$(call bml.prog,latexml: $< → $@)
	@$(if $(bml.is.win),attrib -r "$(call bml.ospath,$(@D))")
	@$(call bml.cmd,$(LATEXML) --preamble=literal:\RequirePackage{bookml/bookml-init} \
	  $(LATEXMLFLAGS) $(LATEXMLEXTRAFLAGS) --log="$(AUX_DIR)/latexmlaux/$*.latexml.log" --destination="$@" "$<")

$(AUX_DIR)/xml/%.preprocessed-xml: $(AUX_DIR)/xml/%.xml $(BOOKML_DEPS_PREPROCESS)
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-preprocess-xml.xsl "$<" --output "$@" --stringparam AUX_DIR "$(AUX_DIR)" $(if $(PDFTOSVG_CONVERTER),,--stringparam AUTOSVG ""))

# build HTML and deps files

# discover postprocessing dependencies (including bmluser/ files, alternative formats, images)
# save in .htmldeps- to avoid rebuilding these files when not required
$(AUX_DIR)/deps/%.htmldeps-: $(AUX_DIR)/xml/%.xml $(BOOKML_DEPS_HTMLDEPS) | $(AUX_DIR)/deps
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-resources.xsl "$<" --output "$@" --stringparam BML_TARGET "$(AUX_DIR)/html/$*/index.html" $(if $(PDFTOSVG_CONVERTER),,--stringparam AUTOSVG ""))

BMLGOALS.HTML := $(patsubst $(AUX_DIR)/html/%/index.html,%,$(filter $(AUX_DIR)/html/%/index.html,$(BMLGOALS)))
BMLGOALS.HTMLDEPS := $(patsubst %,$(AUX_DIR)/deps/%.htmldeps,$(BMLGOALS.HTML))

ifneq ($(BMLGOALS.HTMLDEPS),)
$(BMLGOALS.HTMLDEPS): $(AUX_DIR)/deps/%.htmldeps: $(AUX_DIR)/deps/%.htmldeps-
	@$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$@)"
-include $(patsubst %,$(AUX_DIR)/deps/%.htmldeps,$(BMLGOALS.HTML))
endif
-include $(filter-out $(BMLGOALS.HTMLDEPS),$(wildcard $(AUX_DIR)/deps/*.htmldeps))

# build recursively to force inclusion of htmldeps files
$(filter $(AUX_DIR)/html/%/index.html,$(BMLGOALS)): $(AUX_DIR)/html/%/index.html: $(AUX_DIR)/xml/%.preprocessed-xml $(BOOKML_DEPS_HTML) | $(AUX_DIR)/html
	@$(call bml.prog,latexmlpost: $*.xml → $(AUX_DIR)/html/$*/index.html)
	@$(call bml.rmdir,$(AUX_DIR)/html/$*)
	@$(call bml.cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl) \
	  $(if $(SPLITAT),--splitat=$(SPLITAT)) --urlstyle=file --pmml --mathtex \
		$(LATEXMLPOSTFLAGS) $(LATEXMLPOSTEXTRAFLAGS) --xsltparameter=BMLSEARCH:yes --sourcedirectory=. $(LATEXMLPOSTAUTOFLAGS) \
	  --dbfile=$(AUX_DIR)/latexmlaux/"$*".LaTeXML.db --log="$(AUX_DIR)/latexmlaux/$*.latexmlpost.log" --destination="$@" "$<")
	@$(call bml.cmd,$(PERL) bookml/search_index.pl "$(AUX_DIR)/html/$*")

$(AUX_DIR)/html/%/index.html: $(AUX_DIR)/xml/%.preprocessed-xml $(BOOKML_DEPS_HTML) FORCE | $(AUX_DIR)/html
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) "$@" "BMLGOALS=$@"

# copy zip and SCORM files from $(AUX_DIR) to main folder
$(subst $(bml.spc),\ ,$(CURDIR))/%.zip %.zip: $(AUX_DIR)/html/%.zip
	@$(call bml.cmd,$(CP) "$(call bml.ospath,$<)" "$(call bml.ospath,$@)")

# package HTML output and manifest into SCORM package
$(AUX_DIR)/html/SCORM.%.zip: $(AUX_DIR)/html/%/imsmanifest.xml
	@$(call bml.prog,SCORM: $* → $@)
	@$(call bml.rm,$@)
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)html$(bml.pathsep)$*") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "..$(bml.pathsep)SCORM.$*.zip" . "$(ZIP_EXCLUDE)LaTeXML.cache")

# prevent make from trying to build the files in $(AUX_DIR)/html for which we have no recipe
$(foreach f,$(call bml.reclist.file,$(AUX_DIR)/html),$(eval $(f):))

# package HTML output into zip file
$(AUX_DIR)/html/%.zip: $$(AUX_DIR)/html/$$*/index.html $$(filter-out $$(AUX_DIR)/html/$$*/index.html $$(AUX_DIR)/html/$$*/imsmanifest.xml $$(AUX_DIR)/html/$$*/LaTeXML.cache,$$(call bml.reclist.file,$$(AUX_DIR)/html/$$*))
	@$(call bml.prog,zip: $(AUX_DIR)/html/$* → $@)
	@$(call bml.rm,$@)
	@$(call bml.cmd,cd "$(AUX_DIR)$(bml.pathsep)html") $(bml;) $(call bml.cmd,$(ZIP) --quiet --recurse-paths "$*.zip" "$*" "$(ZIP_EXCLUDE)$*$(bml.pathsep)LaTeXML.cache" "$(ZIP_EXCLUDE)$*$(bml.pathsep)imsmanifest.xml")

# create BookML minimal manifest (a list of files generated by latexmlpost in XML format)
$(AUX_DIR)/latexmlaux/%.manifest: $$(AUX_DIR)/html/$$*/index.html bookml/manifest.pl $$(filter-out $$(AUX_DIR)/html/$$*/index.html $$(AUX_DIR)/html/$$*/imsmanifest.xml $$(AUX_DIR)/html/$$*/LaTeXML.cache,$$(call bml.reclist.file,$$(AUX_DIR)/html/$$*)) | $$(AUX_DIR)/latexmlaux
	@$(call bml.cmd,$(PERL) bookml/manifest.pl "$(AUX_DIR)/html/$*" "$@")

# create SCORM manifest
$(AUX_DIR)/html/%/imsmanifest.xml: $(AUX_DIR)/xml/%.xml $(AUX_DIR)/latexmlaux/%.manifest $(BOOKML_DEPS_IMSMANIFEST) | $(AUX_DIR)/html
	@$(call bml.prog,SCORM manifest: $*.xml → $@)
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-imsmanifest.xsl "$<" --output "$@" \
	   --stringparam BML_MANIFEST "../latexmlaux/$*.manifest")

# image conversions
# match EPS first, as dvisvgm is more reliable with it
bmlimages/svg/%.svg: $$(bml.svg.parent)%.eps $$(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(call bml.cmd,$(DVISVGM) $(DVISVGMFLAGS) --eps "$<" --output="$@")
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl "$@" --output "$@")
bmlimages/svg/%.svg: $$(bml.svg.parent)%.EPS $$(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(call bml.cmd,$(DVISVGM) $(DVISVGMFLAGS) --eps "$<" --output="$@")
	@$(call bml.cmd,$(PERL) bookml/xsltproc.pl bookml/XSLT/proc-svg.xsl "$@" --output "$@")

bmlimages/svg/%.svg: $$(bml.svg.parent)%.pdf $$(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(bml.pdftosvg)
	@$(bml.pdftosvg.proc)
bmlimages/svg/%.svg: $$(bml.svg.parent)%.PDF $$(BOOKML_DEPS_AUTOSVG) | $$(@D)/./
	@$(bml.pdftosvg)
	@$(bml.pdftosvg.proc)

# /./ disambiguates between %.svg, %.pdf targets and actual folders
# a hack, but required to keep compatibility with GNU make 3.81
bmlimages/svg/%/./:
	@$(call bml.mkdir,$@)
bmlimages/svg/./:
	@$(call bml.mkdir,$@)
