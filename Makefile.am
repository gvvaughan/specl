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

old_NEWS_hash = 198844df9628aa2ca847e9ca4443b1c9


## ------------- ##
## Declarations. ##
## ------------- ##

auxdir = build-aux

EXTRA_DIST		= README.md
CLEANFILES		=
DISTCLEANFILES		=
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

release_extra_dist	=				\
	.autom4te.cfg					\
	.travis.yml					\
	GNUmakefile					\
	bootstrap					\
	travis.yml.in					\
	$(NOTHING_ELSE)

include src/src.mk
include specl/specl.mk
include specs/specs.mk
include build-aux/rockspecs.mk


## ------------ ##
## Local Tests. ##
## ------------ ##

check-local: $(check_local)


## ------------- ##
## Installation. ##
## ------------- ##

install-exec-hook: $(install_exec_hooks)
