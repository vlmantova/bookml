# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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
# (5) how to split into multiple files (section, chapter, etc), set to empty string to disable splitting
SPLITAT ?= section
# (6) source files: by default, all .tex files containing a \documentclass
SOURCES ?= $(foreach f,$(wildcard *.tex),$(if $(call grep,\documentclass,$(f)),$(f)))
# (7) files to be built: by default, a .zip file for each .tex file in $(SOURCES)
TARGETS ?= $(SOURCES:.tex=.zip)
# (8) texfot (optional, disable with TEXFOT=)
TEXFOT      ?= texfot
TEXFOTFLAGS ?= $(if $(TEXFOT),--no-stderr,)
# (9) various terminal commands: by default, use typical Windows or Unix version
ifndef ZIP   # detect zip or miktex-zip on Windows
  ZIP        = $(if $(is.win),$(if $(shell where zip 2>NUL),zip,miktex-zip),zip)
endif
ZIP_EXCLUDE ?= -x
is.win      := $(if $(subst xWindows_NT,,x$(OS)),,true)
CP          := $(if $(is.win),copy,cp)
RMDIR       := $(if $(is.win),rd /s /q,rm -fr --)
RM          := $(if $(is.win),del /f /s /q,rm -f --)
MKDIR       := $(if $(is.win),mkdir,mkdir -p --)
pathsep     := $(if $(is.win),$(strip \),/)
null        := $(if $(is.win),2>NUL,2>/dev/null)

### INTERNAL VARIABLES
LATEXMK_INTFLAGS = -norc -interaction=nonstopmode -halt-on-error -recorder \
  -deps -deps-out="$(DEPS_DIR)/$*.d" -output-directory="$(AUX_DIR)"
BOOKML_DEPS_HTML = $(wildcard LaTeXML-html5.xsl bookml/XSLT/*.xsl \
  bookml/*.rng bookml/CSS/*.css bookml/gitbook/css/fontawesome/*.ttf \
  bookml/gitbook/css/*.css bookml/js/*.js bmluser/*.css)
BOOKML_DEPS_XML  = $(wildcard bookml/*.ltxml bookml/*.rng)

### UTILS
# recursive wildcard (https://stackoverflow.com/a/18258352)
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
# backward compatible file/grep function
ifeq ($(findstring version-3.8,version-$(MAKE_VERSION)),version-3.8)
  ifeq ($(is.win),true)
    bfile = $(shell type $(1))
  else
    bfile = $(shell cat -- $(1))
  endif
else
  bfile = $(file < $(1))
endif
grep = $(findstring $(1),$(call bfile,$(2)))

SOURCES := $(SOURCES)

# help editors detect UTF-8 encoding: ∀x.x=x

# progress output (after GMSL)
space := $(strip) $(strip)
alph  := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
         a b c d e f g h i j k l m n o p q r s t u v w x y z \
         0 1 2 3 4 5 6 7 8 9 ` ~ ! @ \# $$ % ^ & * ( ) - _ = \
         + { } [ ] \ : ; ' " < > , . / ? | →
boxgen = $1$(strip $(eval _t := $(strip $(filter-out $(esc)[%m,$2))) \
  $(foreach a,$(alph),$(eval _t := $$(subst $$a,$1,$(_t)))) \
  $(subst $(space),,$(foreach a,$(_t),$a$1)))
boxtop =          $(space)▄$(call                                             boxgen,▄,$1)▄
boxspc = $(space)$(bluebg)▌$(subst ­, ,$(call                                  boxgen,­,$1))▐
boxmid = $(space)$(bluebg)▌ $(strip $(subst $(space)$(esc)[,$(esc)[,$1))$(reset)$(bluebg) ▐
boxbot =          $(space)▀$(call                                             boxgen,▀,$1)▀

cmd      = @$(call echo,$(yellow)$1) $;$1
box      = @$(call echo,$(call boxtop,$1)) $; $(call echo,$(call boxspc,$1)) $; \
  $(call echo,$(call boxmid,$1)) $; $(call echo,$(call boxspc,$1)) $; $(call echo,$(call boxbot,$1))
progress = @$(call box,[$(words $(will.zip) $(will.pdf) $(will.html) $(will.xml))] $1)

esc      := 
cyan     := $(esc)[96m
magenta  := $(esc)[95m
yellow   := $(esc)[93m
green    := $(esc)[92m
red      := $(esc)[91m
blue     := $(esc)[34m
bluebg   := $(esc)[44m
reset    := $(esc)[0m

ifeq ($(is.win),true)
  SHELL    := cmd.exe
  __ignore := $(shell chcp 65001)
  echo      = echo $1$(reset) >&2
else
  echo      = echo "$1$(reset)" >&2
endif
; := $(if $(is.win),&,;)

# painful version comparison
ver.rewrap = $(strip $(eval _x:=$5)$(foreach a,0 1 2 3 4 5 6 7 8 9, \
  $(eval _x:=$(subst $1$a$2,$3$a$4,$(_x))))$(_x))
ver.expl   = $(call ver.rewrap,,, ,,$1)
ver.sep    = $(call ver.rewrap,,, , ,$1)
ver.join   = $(call ver.rewrap,, ,,,$1)
ver.split  = $(strip $(foreach a,$(subst ., ,$1),$(call ver.join,$(call ver.sep,$a))))
ver.pad    = $(strip $(if $(word $(words x $1),$2),$(call ver.pad,0 $1,$2), \
    $(if $(word $(words x $2),$1),$(call ver.pad,$1,0 $2), \
    $(subst $(space),,$1) $(subst $(space),,$2))))
ver.norm   = $(strip $(if $1$2, \
    $(call ver.pad,0 $(call ver.expl,$(firstword $1)!),0 $(call ver.expl,$(firstword $2)!)) \
    $(call ver.norm,$(wordlist 2,$(words $1),$1),$(wordlist 2,$(words $2),$2))))
ver.leq_   = $(strip $(eval _x:=$(firstword $1))$(eval _y:=$(wordlist 2,2,$1)) \
  $(eval _z:=$(wordlist 3,$(words $1),$1))$(if $(_x)$(_y), \
    $(if $(subst 0$(_x),,$(firstword $(sort 0$(_x) 0$(_y)))),, \
      $(if $(subst 0$(_x),,0$(_y)),true,$(call ver.leq_,$(_z)))),true))
ver.leq    = $(call ver.leq_,$(call ver.norm,$(call ver.split,$1),$(call ver.split,$2)))
ver.lt     = $(if $(call ver.leq,$2,$1),,true)

ver.recver = $(strip $(if $3, \
  $(if $(call ver.leq,$1,$3),$(if $(call ver.leq,$2,$3),$(green) $3, \
    $(yellow) $3; recommended $2 or later), \
    $(red) $3; required at least $1$(if $2,; recommended $2 or later)), \
    $(red) NOT FOUND))
testver    = @$(call echo,$(cyan)$1:$(call ver.recver,$2,$3,$4))

openp   = (
closedp = )

# translate file paths if necessary
ospath = $(subst /,$(pathsep),$1)

# Do not delete intermediate files
.SECONDARY:

# Enable second expansion for $$(...) dependencies
.SECONDEXPANSION:

# Delete files on error
.DELETE_ON_ERROR:

.PHONY: all announce-targets clean clean-aux clean-html clean-pdf clean-xml clean-zip \
  debug detect detect-targets detect-make detect-tex detect-perl detect-latexml detect-imagemagick \
  detect-ghostscript detect-dvisvgm detect-latexmk detect-texfot detect-preview detect-zip

all:
all: announce-targets $(TARGETS)
	@$(if $(TARGETS),,$(call progress,Warning: $(red) no .tex files with \documentclass found in this directory))

announce-targets:
	$(call box,Going to build $(yellow) $(TARGETS))

clean: clean-aux clean-html clean-pdf clean-xml clean-zip

clean-aux:
	-$(RM) $(foreach ext,.log .latexml.log .latexmlpost.log .fls $(pathsep)LaTeXML.cache,$(TARGETS:.zip=$(ext)))
	-$(RMDIR) $(subst /,$(pathsep),$(DEPS_DIR) $(AUX_DIR))
clean-html:
	-$(RMDIR) $(TARGETS:.zip=)
clean-pdf:
	-$(RM) $(TARGETS:.zip=.pdf)
clean-xml:
	-$(RM) $(TARGETS:.zip=.xml)
	-$(RMDIR) $(patsubst %.zip,bmlimages/%,$(TARGETS)) $(patsubst %.zip,bmlimages/%-*.svg,$(TARGETS))
clean-zip:
	-$(RM) $(TARGETS)

debug: detect # for backward compatibility
detect: detect-targets detect-make detect-tex detect-perl detect-latexml \
  detect-imagemagick detect-ghostscript detect-dvisvgm detect-latexmk \
  detect-texfot detect-preview detect-zip
detect-targets:
	@$(call echo,$(cyan)   Main files:$(if $(TARGETS) \
	  ,$(green) $(TARGETS:.zip=.tex),$(red) no .tex files with \documentclass found in this directory))
detect-tex:
	$(eval __pre := T)$(eval __post :=)
	$(eval tex_ver := $(subst  , ,$(patsubst $(openp)%,%,$(filter $(openp)%,$(subst $(closedp), , \
	  $(subst $(openp), $(openp),$(subst $(space), ,$(shell tex -version $(null)))))))))
	$(call testver,          TeX,,,$(tex_ver))
detect-make:
	$(call testver,     GNU Make,3.81,,$(MAKE_VERSION))
detect-perl:
	$(eval perl_ver := $(subst $(closedp),,$(subst $(openp),,$(firstword \
	  $(filter $(openp)%,$(shell perl --version $(null)))))))
	$(call testver,         perl,,,$(perl_ver))
detect-latexml:
	$(eval latexml_ver := $(subst $(closedp),,$(filter %$(closedp), \
	  $(shell $(LATEXML) --VERSION 2>&1))))
	$(call testver,      LaTeXML,0.8.5,0.8.6,$(latexml_ver))
detect-imagemagick:
	$(foreach a,Magick Magick::Q16 Magick::Q16HDRI Magick::Q8, \
	  $(if $(magick_ver),,$(eval magick_ver:=$(shell perl -MImage::$a -e "print Image::$a->VERSION" $(null)))))
	$(call testver,Image::Magick,,,$(magick_ver))
detect-ghostscript:
	$(foreach a, \
	  $(if $(is.win),gswin64c gswin64 gswin32c gswin32,gs), \
	  $(if $(gs_ver),,$(eval gs_ver:=$(shell $a -v $(null)))))
	$(call testver,  Ghostscript,,,$(wordlist 3,3,$(gs_ver)))
detect-dvisvgm:
	$(call testver,      dvisvgm,1.6,,$(lastword $(shell dvisvgm --version $(null))))
detect-latexmk:
	$(call testver,      latexmk,,,$(lastword $(shell $(LATEXMK) --version $(null))))
detect-texfot:
	$(call testver,       texfot,,,$(wordlist 3,3,$(shell $(TEXFOT) --version $(null))))
detect-preview:
	$(call testver,  preview.sty,,,$(shell kpsewhich preview.sty $(null)))
detect-zip:
	$(eval zip_ver := $(firstword $(subst Zip_,,\
	  $(filter Zip_%,$(subst Zip$(space),Zip_,$(shell $(ZIP) -v $(null)))))))
	$(call testver,          zip,,,$(zip_ver))

-include $(wildcard $(DEPS_DIR)/*.d)

$(DEPS_DIR):
	$(call cmd,$(MKDIR) "$(subst /,$(pathsep),$@)")

# use relative paths is possible (with extra work if there are spaces)
$(subst $(space),\ ,$(CURDIR))/%.pdf %.pdf: $(AUX_DIR)/%.pdf
	$(call cmd,$(CP) "$(subst /,$(pathsep),$<)" "$(subst /,$(pathsep),$@)")
	-$(call cmd,$(CP) "$(subst /,$(pathsep),$(AUX_DIR)/$*.synctex.gz)" "$(subst /,$(pathsep),$*.synctex.gz)")

$(AUX_DIR)/%.pdf: will.pdf:=x
$(AUX_DIR)/%.pdf: %.tex | $(DEPS_DIR)
	$(call progress,pdflatex: $< → $*.pdf)
	$(call cmd,$(TEXFOT) $(TEXFOTFLAGS) $(LATEXMK) $(LATEKMKFLAGS) $(LATEXMK_INTFLAGS) -g -pdf -dvi- -ps- "$<")

%.xml: will.xml:=x
%.xml: %.tex $(BOOKML_DEPS_XML) %.pdf
	$(call progress,latexml: $< → $@)
	$(call cmd,$(LATEXML) $(if $(call grep,{bookml/bookml},$<),,--preamble=literal:\\RequirePackage{bookml/bookml} \
	) $(LATEXMLFLAGS) --destination="$@" "$<")

%/index.html: will.html:=x
%/index.html: %.xml %.pdf $(BOOKML_DEPS_HTML) $$(wildcard bmlimages/$$**.svg)
	$(call progress,latexmlpost: $< → $@)
	$(call cmd,$(LATEXMLPOST) $(if $(wildcard LaTeXML-html5.xsl),,--stylesheet=bookml/XSLT/bookml-html5.xsl \
	) $(if $(SPLITAT),--splitat=$(SPLITAT)) $(LATEXMLPOSTFLAGS) --destination="$@" "$<")

%.zip: will.zip:=x
%.zip: %/index.html $$(call rwildcard,$$*,*)
	$(call progress,zip: $(<D) → $@)
	-$(call cmd,$(RM) "$(subst /,$(pathsep),$@)")
	$(call cmd,$(ZIP) -r "$@" "$*" "$(ZIP_EXCLUDE)$*$(pathsep)LaTeXML.cache")
