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

ifndef __bml.print.mk.included
__bml.print.mk.included :=

### Console output functions (code inspired by GMSL)

include bookml/bml-version.mk
include bookml/bml-utils.mk

# mimic MAKE_TERMOUT (non-empty if the output goes to a terminal)
ifneq ($(call bml.version.lt,$(MAKE_VERSION),4.1),)
  MAKE_TERMOUT ?= $(if $(bml.utils.iswin),,$(shell tput setaf 1 >/dev/null 2>&1 && echo true))
endif

ifneq ($(MAKE_TERMOUT),)
  # avoid printing escape characters when printing the Make database
  ifeq ($(findstring p,$(bml.utils.makeflags)),)
    bml.print.esc      := 
    bml.print.black    := $(bml.print.esc)[30m
    bml.print.cyan     := $(bml.print.esc)[1;36m
    bml.print.cyanbg   := $(bml.print.esc)[106m
    bml.print.magenta  := $(bml.print.esc)[1;35m
    bml.print.yellow   := $(bml.print.esc)[1;33m
    bml.print.yellowbg := $(bml.print.esc)[103m
    bml.print.green    := $(bml.print.esc)[1;32m
    bml.print.red      := $(bml.print.esc)[1;31m
    bml.print.redbg    := $(bml.print.esc)[101m
    bml.print.blue     := $(bml.print.esc)[34m
    bml.print.white    := $(bml.print.esc)[1;37m
    bml.print.bluebg   := $(bml.print.esc)[44m
    bml.print.reset    := $(bml.print.esc)[0m
    ifneq ($(bml.utils.iswin),)
      # set console codepage to UTF-8
      __bml.print.chcp := $(shell chcp 65001)
    endif
  endif
endif

bml.print.info    = $(info $1$(bml.print.reset))
bml.print.warning = $(warning $(bml.print.yellow)$1$(bml.print.reset))
bml.print.error   = $(error $(bml.print.red)$1$(bml.print.reset))

ifneq ($(bml.utils.iswin),)
  # on Windows, there are curious timing issues when parallel building
  # TODO are they still relevant?
  bml.print.cmd  = $(call bml.print.echo,$(bml.print.cyan)$1) & $1
  bml.print.echo = echo $(subst >,^>,$1)$(bml.print.reset)
else
  bml.print.cmd  = $(call bml.print.echo,$(bml.print.cyan)$1)$1
  bml.print.echo = $(bml.print.info)
endif

bml.print.redbox_    = $(call bml.print.info,$(bml.print.redbg)$(bml.print.white) $(subst $(bml.utils.space)$(bml.print.esc)[,$(bml.print.esc)[,$1)$(bml.print.reset)$(bml.print.redbg) )
bml.print.yellowbox_ = $(call bml.print.info,$(bml.print.yellowbg)$(bml.print.black) $(strip $(subst $(bml.utils.space)$(bml.print.esc)[,$(bml.print.esc)[,$1))$(bml.print.reset)$(bml.print.yellowbg) )

bml.print.redbox    = $(call bml.print.echo,$(bml.print.redbg)$(bml.print.white) $(subst $(bml.utils.space)$(bml.print.esc)[,$(bml.print.esc)[,$1)$(bml.print.reset)$(bml.print.redbg) )
bml.print.yellowbox = $(call bml.print.echo,$(bml.print.yellowbg)$(bml.print.black) $(strip $(subst $(bml.utils.space)$(bml.print.esc)[,$(bml.print.esc)[,$1))$(bml.print.reset)$(bml.print.yellowbg) )
bml.print.recipe    = $(call bml.print.redbox,$1: $2 → $3)

# friendly message checking for minimum and recommended version number
bml.print.recver  = $(strip $(if $3, \
  $(if $(call bml.version.leq,$1,$3),$(if $(call bml.version.leq,$2,$3),$(bml.print.green) $3 OK$(bml.print.reset), \
    $(bml.print.yellow) $3; recommended $2 or later), \
    $(bml.print.red) $3; required at least $1$(if $2,; recommended $2 or later)), \
    $(bml.print.red) NOT FOUND))
bml.print.testver = $(call bml.print.echo,$(bml.print.cyan)$1:$(call bml.print.recver,$2,$3,$4)$(bml.print.reset)$5)

endif # __bml.print.mk_included
