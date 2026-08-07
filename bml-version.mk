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

ifndef bml.version.mk.included
bml.version.mk.included :=

### Version comparison functions (compatible with GNU Make 3.81)

bml.version.rewrap = $(strip $(eval x:=$$5)$(foreach dgt,0 1 2 3 4 5 6 7 8 9, \
  $(eval x:=$$(subst $$1$$(dgt)$$2,$$3$$(dgt)$$4,$$x)))$x)

# separate consecutive digits
bml.version.expl  = $(call bml.version.rewrap,,, ,,$1)
# separate all digits
bml.version.sep   = $(call bml.version.rewrap,,, , ,$1)
# join consecutive digits and following non-digit if present
bml.version.join  = $(call bml.version.rewrap,, ,,,$1)
# split version number by . and non-digit/digit alternations
bml.version.split = $(strip $(foreach cpt,$(subst ., ,$1),$(call bml.version.join,$(call bml.version.sep,$(cpt)))))

# zero pad two sequences of digits to make them of the same length
bml.version.pad_ = $(strip $(if $(word $(words x $1),$2),$(call bml.version.pad_,0 $1,$2), \
  $(if $(word $(words x $2),$1),$(call bml.version.pad_,$1,0 $2), \
  $(subst $(strip ) ,,$1) $(subst $(strip ) ,,$2))))
# zero pad all the components of two version numbers
bml.version.pad  = $(strip $(if $1$2, \
  $(call bml.version.pad_,0 $(call bml.version.expl,$(firstword $1)!),0 $(call bml.version.expl,$(firstword $2)!)) \
  $(call bml.version.pad,$(wordlist 2,$(words $1),$1),$(wordlist 2,$(words $2),$2))))

# compare two split and padded version numbers
bml.version.leq_ = $(strip $(eval _x:=$$(firstword $$1))$(eval _y:=$$(wordlist 2,2,$$1)) \
  $(eval _z:=$$(wordlist 3,$$(words $$1),$$1))$(if $(_x)$(_y), \
    $(if $(subst 0$(_x),,$(firstword $(sort 0$(_x) 0$(_y)))),, \
      $(if $(subst 0$(_x),,0$(_y)),true,$(call bml.version.leq_,$(_z)))),true))

# compare two verison numbers for 'less than or equal'
bml.version.leq = $(call bml.version.leq_,$(call bml.version.pad,$(call bml.version.split,$1),$(call bml.version.split,$2)))
# compare two version numbers for 'less than'
bml.version.lt  = $(if $(call bml.version.leq,$2,$1),,true)

endif # bml.version.mk.included