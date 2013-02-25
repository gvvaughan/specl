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


include yaml/yaml.mk
include src/specl.mk


## ------------ ##
## Local Tests. ##
## ------------ ##

check-local: $(check_local)



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
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

FORCE:
