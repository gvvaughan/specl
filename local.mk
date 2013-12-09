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

# These files are distributed in $(srcdir), and we need to be careful
# not to regenerate them unnecessarily, as that triggers rebuilds of
# dependers that might require tools not installed on the build machine.

LUAM_OPTS = -llarch.from -d
LUAM_ENV = LUA_PATH="./lib/?.lua;$(LUA_PATH)"

specl_DEPS = $(dist_lua_DATA) $(dist_luaspecl_DATA) $(dist_luaformatter_DATA)

$(srcdir)/bin/specl: $(srcdir)/lib/specl.in $(specl_DEPS)
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
	$(AM_V_GEN)sed						\
	  -e 's|@PACKAGE_BUGREPORT''@|$(PACKAGE_BUGREPORT)|g'	\
	  -e 's|@PACKAGE_NAME''@|$(PACKAGE_NAME)|g'		\
	  -e 's|@VERSION''@|$(VERSION)|g'			\
	  -e '/^]]SH/q'						\
	  '$(srcdir)/lib/specl.in' > '$@'
	$(AM_V_at)for f in $(specl_DEPS); do			\
	  m=`echo "$$f" |sed -e 's|^lib/||' -e 's|/|.|g' -e 's|\.lua$$||'`; \
	  { echo 'package.preload["'"$$m"'"] = (function ()';	\
	    $(LUAM_ENV) $(LUAM) $(LUAM_OPTS) $$f;		\
	    echo "end)";					\
	  } >> '$@';						\
	done
	$(AM_V_at)sed						\
	  -e 's|@PACKAGE_BUGREPORT''@|$(PACKAGE_BUGREPORT)|g'	\
	  -e 's|@PACKAGE_NAME''@|$(PACKAGE_NAME)|g'		\
	  -e 's|@VERSION''@|$(VERSION)|g'			\
	  -e '1,/^]]SH/d'					\
	  '$(srcdir)/lib/specl.in' >> '$@'
	$(AM_V_at)chmod 755 '$@'

$(srcdir)/doc/specl.1: $(SPECL)
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
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

man_MANS += doc/specl.1

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
	doc/specl.1					\
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
	doc/specl.1					\
	$(NOTHING_ELSE)
