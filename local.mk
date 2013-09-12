# Local Make rules.
#
# Copyright (C) 2013 Gary V. Vaughan
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


## ---------- ##
## Bootstrap. ##
## ---------- ##

old_NEWS_hash = 6c0ba1b6146ad175724939ecf6852f0f

include specs/specs.mk

## ------ ##
## Build. ##
## ------ ##

docs/specl.1: $(SPECL)
	@test -d docs || mkdir docs
## Exit gracefully if specl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  builddir='$(builddir)'			\
	  $(HELP2MAN)					\
	    '--output=$@'				\
	    '--no-info'					\
	    '--name=Specl'				\
	    $(SPECL);					\
	fi

## Use a builtin rockspec build with root at $(srcdir)/lib
mkrockspecs_args = --module-dir $(srcdir)/lib


## ------------- ##
## Installation. ##
## ------------- ##

man_MANS += docs/specl.1

dist_bin_SCRIPTS += bin/specl

dist_lua_DATA +=					\
	lib/specl.lua					\
	$(NOTHING_ELSE)

luaspecldir = $(luadir)/specl

dist_luaspecl_DATA =					\
	lib/specl/color.lua				\
	lib/specl/loader.lua				\
	lib/specl/matchers.lua				\
        lib/specl/optparse.lua				\
	lib/specl/shell.lua				\
	lib/specl/std.lua				\
	lib/specl/util.lua				\
	$(NOTHING_ELSE)

luaformatterdir = $(luaspecldir)/formatter

dist_luaformatter_DATA =				\
	lib/specl/formatter/progress.lua		\
	lib/specl/formatter/report.lua			\
	lib/specl/formatter/tap.lua			\
	$(NOTHING_ELSE)


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	docs/specl.1					\
	lib/specl.in					\
	$(NOTHING_ELSE)

release_extra_dist =					\
	.autom4te.cfg					\
	.travis.yml					\
	GNUmakefile					\
	bootstrap					\
	local.mk					\
	travis.yml.in					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

CLEANFILES +=						\
	bin/specl					\
	$(NOTHING_ELSE)

DISTCLEANFILES +=					\
	docs/specl.1					\
	$(NOTHING_ELSE)
