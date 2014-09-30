# Local Make rules.
# Written by Gary V. Vaughan, 2013
#
# Copyright (C) 2013-2014 Gary V. Vaughan
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


## ------------ ##
## Environment. ##
## ------------ ##

std_path = $(abs_srcdir)/lib/?.lua
LUA_ENV  = LUA_PATH="$(std_path);$(LUA_PATH)"


## ---------- ##
## Bootstrap. ##
## ---------- ##

old_NEWS_hash = bb7c6d94d56ccf2920aee55c999ffbe8

update_copyright_env = \
	UPDATE_COPYRIGHT_HOLDER='Gary V. Vaughan' \
	UPDATE_COPYRIGHT_USE_INTERVALS=1 \
	UPDATE_COPYRIGHT_FORCE=1


## ------------- ##
## Declarations. ##
## ------------- ##

include specs/specs.mk

## ------ ##
## Build. ##
## ------ ##

dist_bin_SCRIPTS += bin/specl

specldir = $(luadir)/specl

dist_specl_DATA =					\
	lib/specl/badargs.lua				\
	lib/specl/color.lua				\
	lib/specl/compat.lua				\
	lib/specl/inprocess.lua				\
	lib/specl/loader.lua				\
	lib/specl/main.lua				\
	lib/specl/matchers.lua				\
	lib/specl/runner.lua				\
	lib/specl/shell.lua				\
	lib/specl/std.lua				\
	lib/specl/util.lua				\
	lib/specl/version.lua				\
	$(NOTHING_ELSE)

formatterdir = $(specldir)/formatter

dist_formatter_DATA =					\
	lib/specl/formatter/progress.lua		\
	lib/specl/formatter/report.lua			\
	lib/specl/formatter/tap.lua			\
	$(NOTHING_ELSE)

man_MANS += doc/specl.1

$(srcdir)/doc/specl.1: $(srcdir)/specl
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;		\
	test -d "$$d" || $(MKDIR_P) "$$d"
## Exit gracefully if specl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  $(HELP2MAN)					\
	    '--output=$@'				\
	    '--no-info'					\
	    '--name=Specl'				\
	    $(srcdir)/specl;				\
	fi

## Use a builtin rockspec build with root at $(srcdir)/lib.
mkrockspecs_args = --module-dir $(srcdir)/lib


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	doc/specl.1					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

DISTCLEANFILES +=					\
	doc/specl.1					\
	$(NOTHING_ELSE)
