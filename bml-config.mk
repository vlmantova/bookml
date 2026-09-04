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

ifndef __bml.config.mk.included
__bml.config.mk.included :=

### Save per-target configuration

# to use:
# - before the recipe, a call $(call bml.config.set,FORMAT,flags[,...[,EXT]])
#   determining which variables, and possibly other data, is part of its
#   configuration
# - prerequisite $$(call bml.config.prereq,FORMAT)
# - order-only prerequisite $(call bml.config.predir,FORMAT)
# - recipe line $(bml.config.save)

include bookml/bml-utils.mk
include bookml/bml-print.mk

bml.config.dumpvar  = $2=$(subst $$,$$$$,$(call bml.utils.getvar,$1,$2))
bml.config.dumpvars = $(subst $(bml.utils.space)$(bml.utils.nl),$(bml.utils.nl),$(foreach var,$2,$(bml.utils.nl)$(call bml.config.dumpvar,$1,$(var))))
bml.config.dumpconf = \# configuration used for the last successful build$(call bml.config.dumpvars,$1,$(bml.config.save.$(bml.config.type).vars))$(if $(bml.config.save.$(bml.config.type).extra),$(bml.utils.nl)$(bml.config.save.$(bml.config.type).extra))

bml.config.type = $(call bml.utils.filtersubst,BML_UPDATED_CONFIG_%,%,$^)
bml.config.file = $(AUX_DIR)/config/$*.$(bml.config.save.$(bml.config.type).prext)/$(bml.config.type).mk

bml.config.read = $(if $(wildcard $(bml.config.file)),$(call bml.utils.read,$(bml.config.file)))

ifneq ($(call bml.version.leq,4,$(MAKE_VERSION)),)
  # but remember that $(file <) strips the last newline
  bml.config.isstale = $(subst "$1",,"$(call bml.config.dumpconf,$*)")
  bml.config.write   = $(call bml.utils.write,$(bml.config.file),$(call bml.config.dumpconf,$*)$(bml.utils.nl))
else
  # using $(shell ...) strips the output so we lose precision, inevitably
  bml.config.isstale = $(subst "$(strip $1)",,"$(strip $(call bml.config.dumpconf,$*))")
  bml.config.write   = $(call bml.utils.write,$(bml.config.file),$(call bml.config.dumpconf,$*))
endif

bml.config.needsupdate = $(strip $(if $(wildcard $(bml.config.file)-invalid), \
    $(call bml.print.warning,the configuration was not saved correctly! config changes will stop causing recompilation until you delete '$(bml.config.file)-invalid'; please report the issue online), \
    $(eval c:=$$(bml.config.read))$(call bml.config.isstale,$c)))

bml.config.save = $(if $(bml.config.type),$(call bml.print.info,$(bml.print.magenta)recording new configuration for '$(patsubst $(AUX_DIR)/%,%,$@)')$(if $(bml.utils.isdryrun),,$(bml.config.write)$(if $(bml.config.needsupdate),$(call bml.utils.touch,$(bml.config.file)-invalid)$(bml.config.needsupdate))))

define bml.config.set_
.PHONY: BML_UPDATED_CONFIG_$1

bml.config.save.$1.vars  = $2
bml.config.save.$1.extra = $(if $(filter undefined,$(origin 3)),,$3)
bml.config.save.$1.prext = $(if $(filter undefined,$(origin 4)),tex,$4)
endef

# if recording the updates and everything is considered out of date, avoid
# reading the config files
bml.config.set    = $(eval $(bml.config.set_))
bml.config.prereq = $(if $(and $(bml.deps.recordupdates),$(findstring B,$(bml.utils.makeflags))),,$(if $(foreach bml.config.type,$1,$(bml.config.needsupdate)),BML_UPDATED_CONFIG_$1))
bml.config.predir = $(AUX_DIR)/config/%.$(bml.config.save.$1.prext)/./

endif # __bml.config.mk.included
