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


## Use `require "specl.std"` for implementation modules.
nobase_dist_lua_DATA =					\
	specl/formatter/progress.lua			\
	specl/formatter/report.lua			\
	specl/formatter/tap.lua				\
	specl/color.lua					\
	specl/matchers.lua				\
	specl/std.lua					\
	specl/util.lua					\
	specl/version.lua				\
	$(NOTHING_ELSE)
