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

SPECL = src/specl

# Make Lua specs from YAML specs.
.yaml.lua:
	$(AM_V_GEN)build-aux/speclc '$^' > '$@'

specl_SPECS =						\
	$(srcdir)/specs/environment_spec.yaml		\
	$(srcdir)/specs/environment_spec.lua		\
	$(srcdir)/specs/matchers_spec.yaml		\
	$(srcdir)/specs/matchers_spec.lua		\
	$(srcdir)/specs/specl_spec.yaml			\
	$(srcdir)/specs/specl_spec.lua			\
	$(NOTHING_ELSE)

EXTRA_DIST +=						\
	$(specl_SPECS)					\
	$(NOTHING_ELSE)

check-local: src/specl $(specl_SPECS)
	$(AM_V_at)$(LUA) $(SPECL) $(specl_SPECS)
