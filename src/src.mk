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


## ------------- ##
## Declarations. ##
## ------------- ##

INSTALL_PATH  = $(luadir)/?.lua

specl_install_edit =					\
	$(install_edit)					\
	-e 's|@speclpath[@]|$(INSTALL_PATH)|g'		\
	$(NOTHING_ELSE)


INPLACE_PATH  = $(abs_srcdir)/src/?.lua;$(abs_srcdir)/?.lua

specl_inplace_edit =					\
	$(inplace_edit)					\
	-e 's|@speclpath[@]|$(INPLACE_PATH)|g'		\
	$(NOTHING_ELSE)


## ------ ##
## Build. ##
## ------ ##

bin_SCRIPTS += bin/specl

man_MANS += docs/specl.1

## But, `require "specl"` for core module.
dist_lua_DATA =						\
	src/specl.lua					\
	$(NOTHING_ELSE)

bin/specl: Makefile src/specl.in
	@test -d bin || mkdir bin
	@rm -f '$@' '$@.tmp'
	$(AM_V_GEN)$(specl_inplace_edit) '$(srcdir)/src/specl.in' >'$@.tmp'
	$(AM_V_at)mv '$@.tmp' '$@'
	$(AM_V_at)chmod +x '$@'
	$(AM_V_at)$@ --version >/dev/null || : rm '$@'

docs/specl.1: bin/specl specl/version.lua
	@test -d docs || mkdir docs
## Exit gracefully if specl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  builddir='$(builddir)'			\
	  $(HELP2MAN)					\
	    '--output=$@'				\
	    '--no-info'					\
	    '--name=Specl'				\
	    bin/specl;					\
	fi


## ------------- ##
## Installation. ##
## ------------- ##

install_exec_hooks += install-specl-hook
install-specl-hook:
	@$(specl_install_edit) $(srcdir)/src/specl.in >'$@.tmp'
	@echo $(INSTALL_SCRIPT) bin/specl $(DESTDIR)$(bindir)/specl
	@$(INSTALL_SCRIPT) $@.tmp $(DESTDIR)$(bindir)/specl
	@rm -f $@.tmp


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	docs/specl.1					\
	src/specl.in					\
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
