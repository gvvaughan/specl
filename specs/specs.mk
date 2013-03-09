# Specl make rules.
#
# Copyright (c) 2013 Gary V. Vaughan
# Written by Gary V. Vaughan, 2013
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


## ------ ##
## Tools. ##
## ------ ##

check_SCRIPTS = build-aux/speclc

build_aux_speclc_DEPS =					\
	Makefile					\
	build-aux/speclc.in				\
	$(NOTHING_ELSE)

build-aux/speclc: $(build_aux_speclc_DEPS)
	@test -d build-aux || mkdir build-aux
	@rm -f '$@' '$@.tmp'
	$(AM_V_GEN)$(specl_inplace_edit) '$(srcdir)/$@.in' >'$@.tmp'
	$(AM_V_at)mv '$@.tmp' '$@'
	$(AM_V_at)chmod +x '$@'

EXTRA_DIST += build-aux/speclc.in

DISTCLEANFILES += build-aux/speclc


## ------ ##
## Specs. ##
## ------ ##

SPECL  = specl/specl
SPECLC = build-aux/speclc


specl_SPECS =						\
	$(srcdir)/specs/environment_spec.yaml		\
	$(srcdir)/specs/matchers_spec.yaml		\
	$(srcdir)/specs/specl_spec.yaml			\
	$(NOTHING_ELSE)

specl_LUASPECS =					\
	specs/environment_spec.lua			\
	specs/matchers_spec.lua				\
	specs/specl_spec.lua				\
	$(NOTHING_ELSE)

# Make Lua specs from YAML specs.
.yaml.lua:
	@test -d specs || mkdir specs
	$(AM_V_GEN)$(SPECLC) '$^' > '$@'

# Lua specs require speclc compiler.
$(specl_LUASPECS): $(SPECLC)

check-local: $(SPECL) $(specl_SPECS) $(specl_LUASPECS)
	$(AM_V_at)$(LUA) $(SPECL) $(specl_SPECS) $(specl_LUASPECS)


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	$(specl_SPECS)					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

DISTCLEANFILES +=					\
	$(specl_LUASPECS)				\
	$(NOTHING_ELSE)
