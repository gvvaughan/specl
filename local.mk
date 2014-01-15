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


## ---------- ##
## Bootstrap. ##
## ---------- ##

old_NEWS_hash = 7a587ba98ed0457bc660bbf8bd0daf1e

update_copyright_env = \
	UPDATE_COPYRIGHT_HOLDER='Gary V. Vaughan' \
	UPDATE_COPYRIGHT_USE_INTERVALS=1 \
	UPDATE_COPYRIGHT_FORCE=1

include specs/specs.mk

## ------ ##
## Build. ##
## ------ ##

LARCH     = $(srcdir)/build-aux/larch

LUAM_OPTS = -llarch.from -d
LUAM_ENV  = LUA_PATH="$(srcdir)/lib/?.lua;$(LUA_PATH)"

# These files are distributed in $(srcdir), and we need to be careful
# not to regenerate them unnecessarily, as that triggers rebuilds of
# dependers that might require tools not installed on the build machine.

$(srcdir)/bin/specl: $(dist_noinst_DATA)
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
	$(AM_V_GEN)$(LARCH) -e 'require "main"' $(dist_noinst_DATA) \
	| sed							\
	  -e 's|@PACKAGE_BUGREPORT''@|$(PACKAGE_BUGREPORT)|g'	\
	  -e 's|@PACKAGE_NAME''@|$(PACKAGE_NAME)|g'		\
	  -e 's|@VERSION''@|$(VERSION)|g' > '$@T'
	$(AM_V_at)$(LUAM_ENV) $(LUAM) $(LUAM_OPTS) '$@T' > '$@'
	$(AM_V_at)rm -f '$@T'
	$(AM_V_at)chmod 755 '$@'

$(srcdir)/doc/specl.1: $(srcdir)/bin/specl
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
## Exit gracefully if specl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  $(LUAM_ENV)					\
	  builddir='$(builddir)'			\
	  $(HELP2MAN)					\
	    '--output=$@'				\
	    '--no-info'					\
	    '--name=Specl'				\
	    $(srcdir)/bin/specl;			\
	fi


## ------------- ##
## Installation. ##
## ------------- ##

man_MANS += doc/specl.1

dist_bin_SCRIPTS += bin/specl

dist_noinst_DATA =					\
	lib/main.lua					\
	lib/specl.lua					\
	lib/specl/color.lua				\
	lib/specl/formatter/progress.lua		\
	lib/specl/formatter/report.lua			\
	lib/specl/formatter/tap.lua			\
	lib/specl/loader.lua				\
	lib/specl/matchers.lua				\
        lib/specl/optparse.lua				\
	lib/specl/shell.lua				\
	lib/specl/std.lua				\
	lib/specl/util.lua				\
	$(NOTHING_ELSE)


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	doc/specl.1					\
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
