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

old_NEWS_hash = cc72f2d86bd849eb07a52e15aee06161

doc_DATA	=

install_edit	= sed					\
	-e 's|@LUA[@]|$(LUA)|g'				\
	$(NOTHING_ELSE)

inplace_edit	= sed					\
	-e 's|@LUA[@]|$(LUA)|g'				\
	$(NOTHING_ELSE)

release_extra_dist =					\
	.autom4te.cfg					\
	.travis.yml					\
	GNUmakefile					\
	bootstrap					\
	local.mk					\
	travis.yml.in					\
	$(NOTHING_ELSE)

include specl/specl.mk
