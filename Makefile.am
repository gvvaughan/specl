# Non-recursive Make rules.
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


## ------------ ##
## Environment. ##
## ------------ ##

LUA_PATH ?= ;


## ---------- ##
## Bootstrap. ##
## ---------- ##

ACLOCAL_AMFLAGS = -I m4


## ------------- ##
## Declarations. ##
## ------------- ##

CLEANFILES		=
DISTCLEANFILES		=
EXTRA_DIST		=
MAINTAINERCLEANFILES	=
NOTHING_ELSE		=

bin_SCRIPTS		=
check_local		=
doc_DATA		=
install_exec_hooks	=
man_MANS		=

install_edit = sed					\
	-e 's|@LUA[@]|$(LUA)|g'				\
	$(NOTHING_ELSE)

inplace_edit = sed					\
	-e 's|@LUA[@]|$(LUA)|g'				\
	$(NOTHING_ELSE)


include src/src.mk
include specl/specl.mk
include specs/specs.mk


## ------------ ##
## Local Tests. ##
## ------------ ##

check-local: $(check_local)


## --------- ##
## LuaRocks. ##
## --------- ##

LUAROCKS	 ?= luarocks
MKROCKSPECS	  = $(LUA) $(srcdir)/build-aux/mkrockspecs
ROCKSPEC_TEMPLATE = $(srcdir)/rockspecs.lua
RELEASE_ROCKSPEC  = $(srcdir)/$(PACKAGE)-$(VERSION)-1.rockspec
GIT_ROCKSPEC      = $(PACKAGE)-git-1.rockspec

ROCKSPECS_DEPS =				\
	luarocks-config.lua			\
	$(srcdir)/build-aux/mkrockspecs		\
	$(ROCKSPEC_TEMPLATE)			\
	$(NOTHING_ELSE)

set_LUA_BINDIR ?= LUA_BINDIR=`which $(LUA) |$(SED) 's|/[^/]*$$||'`
LUA_INCDIR ?= `cd $$LUA_BINDIR/../include && pwd`
LUA_LIBDIR ?= `cd $$LUA_BINDIR/../lib && pwd`

luarocks-config.lua: Makefile.am
	$(AM_V_GEN){						\
	  $(set_LUA_BINDIR);					\
	  echo 'rocks_trees = { "$(abs_srcdir)/luarocks" }';	\
	  echo 'variables = {';					\
	  echo '  LUA = "$(LUA)",';				\
	  echo '  LUA_BINDIR = "'$$LUA_BINDIR'",';		\
	  echo '  LUA_INCDIR = "'$(LUA_INCDIR)'",';		\
	  echo '  LUA_LIBDIR = "'$(LUA_LIBDIR)'",';		\
	  echo '}';						\
	} > '$@'

$(RELEASE_ROCKSPEC): $(ROCKSPECS_DEPS)
	$(AM_V_at)rm -f '$@' 2>/dev/null || :
	$(AM_V_GEN)test -f '$@' ||				\
	  $(MKROCKSPECS) $(PACKAGE) $(VERSION) $(ROCKSPEC_TEMPLATE) > '$@'
	$(AM_V_at)$(LUAROCKS) lint '$@'


$(GIT_ROCKSPEC): $(ROCKSPECS_DEPS)
	$(AM_V_at)rm '$@' 2>/dev/null || :
	$(AM_V_GEN)test -f '$@' ||				\
	  $(MKROCKSPECS) $(PACKAGE) git $(ROCKSPEC_TEMPLATE) > '$@'
	$(AM_V_at)$(LUAROCKS) lint '$@'

.PHONY: rockspecs
rockspecs: $(RELEASE_ROCKSPEC) $(GIT_ROCKSPEC)


## ------------- ##
## Installation. ##
## ------------- ##

install-exec-hook: $(install_exec_hooks)


## ------------- ##
## Distribution. ##
## ------------- ##

gitlog_to_changelog	= $(srcdir)/build-aux/gitlog-to-changelog

dist-hook: ChangeLog
ChangeLog: FORCE
	$(AM_V_GEN)if test -d '$(srcdir)/.git'; then	\
	  $(gitlog_to_changelog) > '$@T';		\
	  rm -f '$@'; mv '$@T' '$@';			\
	fi

EXTRA_DIST +=						\
	GNUmakefile					\
	README.md					\
	build-aux/do-release-commit-and-tag		\
	rockspecs.lua					\
	$(RELEASE_ROCKSPEC)				\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

DISTCLEANFILES += luarocks-config.lua

FORCE:
