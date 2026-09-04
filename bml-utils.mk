# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-26 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
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

ifndef __bml.utils.mk.included
__bml.utils.mk.included :=

### Various utility functions

include bookml/bml-version.mk

bml.utils.isdryrun := $(findstring n,$(firstword -$(MAKEFLAGS)))
bml.utils.iswin    := $(filter Windows_NT,$(if $(filter-out undefined,$(origin OS)),$(OS)))

# escape command line arguments that are empty or contain spaces and 'special
# characters', which for simplicity is the union of sh_chars_dos, sh_chars_sh,
# etc (see construct_command_argv_internal in job.c)
bml.utils.needsescapearg = $(or \
  $(filter "","$1"), \
  $(filter-out 1,$(words "$1")), \
  $(strip $(foreach chr,\# ; " * ? [ ] & | < > ( ) { } $$ ` ^ ~ ' % !,$(findstring $(chr),$1))))
ifneq ($(bml.utils.iswin),)
  # wrap in double quotes, where n backslashes before " or at the end of
  # the string are replaced with 2n+1 backslashes
  bml.utils.doubleslashes = $(if $(findstring $2\",$1),$(call bml.utils.doubleslashes,$(subst $2\",$2\\",$1),\\$2),$1)
  bml.utils.escapearg_    = "$(subst \"",",$(subst ",\",$(call bml.utils.doubleslashes,$1",))")
else
  # wrap in single quotes, replace ' with '"'"'
  bml.utils.escapearg_  = '$(subst ','"'"',$1)'
endif

bml.utils.escapearg  = $(if $(call bml.utils.needsescapearg,$1),$(call bml.utils.escapearg_,$1),$1)

bml.utils.seq_        = $(if $(filter $1,$(words $2)),$2,$(call bml.utils.seq_,$1,$2 $(words $2 1)))
bml.utils.seq         = $(call bml.utils.seq_,$1,)
$(foreach num,1 2 3 4 5 6 7 8 9,$(eval bml.utils.escape$(num)args =$(foreach idx,$(call bml.utils.seq,$(num)),$$(call bml.utils.escapearg,$$$(idx)))))

# portable commands
ifneq ($(bml.utils.iswin),)
  SHELL             := cmd.exe
  bml.utils.ospath   = $(subst /,\,$1)
  bml.utils.pathsep := $(strip \)
  bml.utils.null    := NUL
  bml.utils.;       := &
else
  bml.utils.ospath   = $1
  bml.utils.pathsep := /
  bml.utils.null    := /dev/null
  bml.utils.;       := ;
endif

# portable 'which'
ifneq ($(bml.utils.iswin),)
  bml.utils.which = $(shell where $(call bml.utils.escapearg,$1) 2>NUL)
else
  bml.utils.which = $(shell command -v $(call bml.utils.escapearg,$1))
endif

# portable read/touch/write file
ifneq ($(bml.utils.iswin),)
  bml.utils.readcmd  = type $(call bml.utils.escapearg,$(call bml.utils.ospath,$1))
  bml.utils.touchcmd = echo:> $(call bml.utils.escapearg,$(call bml.utils.ospath,$1))
  bml.utils.writecmd = ( echo:$(subst $(bml.utils.nl),& echo:,$(subst >,^>,$2)) ) > $(call bml.utils.escapearg,$(call bml.utils.ospath,$1))
else
  bml.utils.readcmd  = cat -- $(call bml.utils.escapearg,$1)
  bml.utils.touchcmd = touch -- $(call bml.utils.escapearg,$1)
  bml.utils.writecmd = printf $(call bml.utils.escapearg,$(subst $(bml.utils.nl),\n,$2)\n) > $(call bml.utils.escapearg,$1)
endif

ifneq ($(call bml.version.lt,$(MAKE_VERSION),4),)
  bml.utils.read  = $(shell $(call bml.utils.readcmd,$1))
  bml.utils.touch = $(if $(bml.utils.isdryrun),,$(shell $(call bml.utils.touchcmd,$1)))
  bml.utils.write = $(if $(bml.utils.isdryrun),,$(shell $(call bml.utils.writecmd,$1,$2)))
else
  bml.utils.read  = $(file < $1)
  bml.utils.touch = $(if $(bml.utils.isdryrun),,$(file > $1,))
  bml.utils.write = $(if $(bml.utils.isdryrun),,$(file > $1,$2))
endif

# portable 'touch -r' / 'robocopy'
ifneq ($(bml.utils.iswin),)
  bml.utils.copytimestamp = $(if $(filter-out $(notdir $1),$(notdir $2)),\
    $$(call bml.print.error,files '$1' and '$2' must have the same name),\
    if exist $(call bml.utils.escapearg,$(call bml.utils.ospath,$2)) $(ROBOCOPY) /COPY:TX /DCOPY:TX /NJH /NJS /NFL /NDL /IM /IS /IT /TIMFIX $(call bml.utils.escapearg,$(call bml.utils.ospath,$(patsubst %/,%,$(dir $1)))) $(call bml.utils.escapearg,$(call bml.utils.ospath,$(patsubst %/,%,$(dir $2))),$(call bml.utils.ospath,$(notdir $1)))) || :
else
  # keep the error as on Windows for ease of debugging
  bml.utils.copytimestamp = $(if $(filter-out $(notdir $1),$(notdir $2)),\
    $$(call bml.print.error,files '$1' and '$2' must have the same name),\
    [ ! -f $(call bml.utils.escapearg,$2) ] || $(TOUCH) -r $(call bml.utils.escape2args,$1,$2))
endif

bml.utils.timestampfile    = $(patsubst %,$(AUX_DIR)/timestamp/%.tex/$(@F),$*)
bml.utils.savetimestamp    = $(call bml.utils.touch,$(bml.utils.timestampfile))
bml.utils.restoretimestamp = $(call bml.utils.copytimestamp,$(bml.utils.timestampfile),$@)
bml.utils.tsprereq         = $(AUX_DIR)/timestamp/%.tex/./

# portable 'grep'
bml.utils.grep = $(findstring $1,$(call bml.utils.read,$2))

# list entire file tree (directories end with /)
bml.utils.tree = $(foreach dir,$1,$(if $(wildcard $(dir)/./),$(dir)/./ $(call bml.utils.tree,$(wildcard $(dir)/*)),$(dir)))

# list only leaves of file tree
bml.utils.leaves   = $(foreach dir,$1,$(if $(wildcard $(dir)/*),$(call bml.utils.leaves,$(wildcard $(dir)/*)),$(if $(wildcard $(dir)/./),$(dir)/./,$(dir))))
# list only leaves of directory tree
bml.utils.leafdirs = $(foreach dir,$(1:/./=),$(if $(wildcard $(dir)/*/./),$(call bml.utils.leafdirs,$(wildcard $(dir)/*/./)),$(dir)/./))

ifneq ($(bml.utils.iswin),)
  bml.utils.mkdir = if not exist $(call bml.utils.escapearg,$(call bml.utils.ospath,$(if $(filter %/,$1),$1,$1/))) $(MKDIR) $(call bml.utils.escapearg,$(call bml.utils.ospath,$1))
  bml.utils.rm    = if exist $(call bml.utils.escapearg,$(call bml.utils.ospath,$1)) $(RM) $(call bml.utils.escapearg,$(call bml.utils.ospath,$1))
  bml.utils.rmdir = if exist $(call bml.utils.escapearg,$(call bml.utils.ospath,$(if $(filter %/,$1),$1,$1/))) $(RMDIR) $(call bml.utils.escapearg,$(call bml.utils.ospath,$1))
  bml.utils.cp    = if exist $(call bml.utils.escapearg,$(call bml.utils.ospath,$1)) $(CP) $(call bml.utils.escape2args,$(call bml.utils.ospath,$1),$(call bml.utils.ospath,$2))
  bml.utils.mv    = if exist $(call bml.utils.escapearg,$(call bml.utils.ospath,$1)) $(MV) $(call bml.utils.escape2args,$(call bml.utils.ospath,$1),$(call bml.utils.ospath,$2))
else
  bml.utils.mkdir = $(MKDIR) $(call bml.utils.escapearg,$(if $(filter %/,$1),$1,$1/))
  bml.utils.rm    = $(RM) $(call bml.utils.escapearg,$1)
  bml.utils.rmdir = $(RMDIR) $(call bml.utils.escapearg,$1)
  bml.utils.cp    = [ ! -f $(call bml.utils.escapearg,$1) ] || $(CP) $(call bml.utils.escape2args,$1,$2)
  bml.utils.mv    = [ ! -f $(call bml.utils.escapearg,$1) ] || $(MV) $(call bml.utils.escape2args,$1,$2)
endif

# per-target configuration variables
# jobname is simplified roughly like Automake to ensure it can be part of a variable name
# variables ending in FLAGS are appended, not replaced
bml.utils.tovar   = $(subst /,_,$(subst \#,_,$(subst -,_,$(subst =,_,$(subst +,_,$1)))))
bml.utils.makevar = $(call bml.utils.tovar,$1)_$2
bml.utils.getvar  = $(eval v:=$$(call bml.utils.makevar,$$1,$$2))$(if $(filter undefined,$(origin $v)),$($2),$(if $(filter %FLAGS,$2),$($2)$(if $(and $($2),$($v)), )$($v),$($v)))
bml.utils.autovar = $(call bml.utils.getvar,$(if $*,$*,$(basename $(@F))),$1)

# convenience variables
bml.utils.openp   := (
bml.utils.closedp := )
bml.utils.comma   := ,
bml.utils.space   := $(strip ) $(strip )
bml.utils.tab     := $(strip )	$(strip )
define bml.utils.nl


endef

# filter and patsubst in a single function
bml.utils.filtersubst = $(patsubst $1,$2,$(filter $1,$3))

# canonicalise to relative path, if in the current folder
bml.utils.relpath = $(if $(filter ::$(CURDIR)/%,::$(abspath $1)),$(subst ::$(CURDIR)/,,::$(abspath $1)))

# make all the default target
all:

# simplify MAKECMDGOALS
bml.utils.makecmdgoals = $(if $(MAKECMDGOALS),$(MAKECMDGOALS),$(.DEFAULT_GOAL))

# split MAKEFLAGS
# MAKEFLAGS is of the form 'flags options -- args', where:
# - 'flags' omits the initial - and may be empty
# - '--' is omitted if there are no args
# - 'args' contains variable assignments only, not the goals
bml.utils.before = $(strip $(if $2,\
  $(if $(filter $1,$(firstword $2)),,\
    $(firstword $2) $(call bml.utils.before,$1,$(wordlist 2,$(words $2),$2)))))
bml.utils.after  = $(strip $(if $2,\
  $(if $(filter $1,$(firstword $2)),$(wordlist 2,$(words $2),$2),\
    $(call bml.utils.after,$1,$(wordlist 2,$(words $2),$2)))))

bml.utils.makeflags = $(filter-out -,$(firstword -$(MAKEFLAGS)))
bml.utils.makeopts  = $(call bml.utils.before,--,$(wordlist 2,$(words -$(MAKEFLAGS)),-$(MAKEFLAGS)))
bml.utils.makeargs  = $(call bml.utils.after,--,$(MAKEFLAGS))

# recognise latexml_oxide
bml.utils.ifoxide = $(findstring oxide,$(notdir $(call bml.utils.autovar,LATEXML)))

endif # __bml.utils.mk.included
