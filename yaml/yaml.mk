## yaml.mk -- included by $(top_srcdir)/Makefile.am
##
## Copyright (C) 2013 Gary V. Vaughan
## Written by Gary V. Vaughan, 2013

## This is free software; see the source for copying conditions.  There is NO
## warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License as
## published by the Free Software Foundation; either version 3 of
## the License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with GNU Libtool; see the file COPYING.  If not, a copy
## can be downloaded from  http://www.gnu.org/licenses/gpl.html,
## or obtained by writing to the Free Software Foundation, Inc.,
## 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#####

luaexec_LTLIBRARIES = yaml/lyaml.la

yaml_lyaml_la_LDFLAGS  = -module -avoid-version
yaml_lyaml_la_CPPFLAGS = $(LUA_INCLUDE) $(YAML_INCLUDE)

EXTRA_DIST +=				\
	yaml/lua52compat.h		\
	$(NOTHING_ELSE)
