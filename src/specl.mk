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


## ------------ ##
## Environment. ##
## ------------ ##

SPECL_PATH  = $(abs_srcdir)/src/?.lua
SPECL_CPATH = $(abs_builddir)/yaml/$(objdir)/?$(shrext)


## ------------- ##
## Declarations. ##
## ------------- ##

specl_install_edit =					\
	$(install_edit)					\
	-e 's|@speclpath[@]|$(pkgluadir)/?.lua|g'	\
	-e 's|@speclcpath[@]|$(libdir)/?$(shrext)|g'	\
	$(NOTHING_ELSE)

specl_inplace_edit =					\
	$(inplace_edit)					\
	-e 's|@speclpath[@]|$(SPECL_PATH)|g'		\
	-e 's|@speclcpath[@]|$(SPECL_CPATH)|g'		\
	$(NOTHING_ELSE)


## ------ ##
## Build. ##
## ------ ##

bin_SCRIPTS += src/specl

man_MANS += docs/specl.1

dist_pkglua_DATA =					\
	src/specl.lua					\
	src/version.lua					\
	$(NOTHING_ELSE)

src_specl_DEPS =					\
	Makefile					\
	src/specl.in					\
	$(dist_pkglua_DATA)				\
	$(NOTHING_ELSE)

src/specl: $(src_specl_DEPS)
	@rm -f '$@' '$@.tmp'
	$(AM_V_GEN)$(specl_inplace_edit) '$(srcdir)/$@.in' >'$@.tmp'
	$(AM_V_at)mv '$@.tmp' '$@'
	$(AM_V_at)chmod +x '$@'
	$(AM_V_at)$@ --version >/dev/null || : rm '$@'

docs/specl.1: docs/specl.1.in Makefile config.status
	@test -d docs || mkdir docs
	$(AM_V_at)rm -f $@ $@.tmp
	$(AM_V_GEN)$(specl_install_edit) '$(srcdir)/$@.in' >'$@.tmp'
	$(AM_V_at)mv '$@.tmp' '$@'

docs/specl.1.in: src/specl src/version.lua
	@test -d docs || mkdir docs
## Exit gracefully if specl.1.in is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  builddir='$(builddir)'			\
	  $(srcdir)/build-aux/missing --run		\
	    $(HELP2MAN)					\
	      '--output=$@'				\
	      '--no-info'				\
	      '--name=Specl'				\
	      src/specl;				\
	fi


## ------------- ##
## Installation. ##
## ------------- ##

install_exec_hooks += install-specl-hook
install-specl-hook:
	@$(specl_install_edit) $(srcdir)/src/specl.in >'$@.tmp'
	@echo $(INSTALL_SCRIPT) src/specl $(DESTDIR)$(bindir)/specl
	@$(INSTALL_SCRIPT) $@.tmp $(DESTDIR)$(bindir)/specl
	@rm -f $@.tmp


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	build-aux/mkrockspecs.lua			\
	docs/specl.1.in					\
	src/specl.in					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

CLEANFILES +=						\
	docs/specl.1					\
	src/specl					\
	$(NOTHING_ELSE)

DISTCLEANFILES +=					\
	docs/specl.1.in					\
	$(NOTHING_ELSE)
