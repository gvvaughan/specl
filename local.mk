# Local Make rules.
# Written by Gary V. Vaughan, 2013
#
# Copyright (C) 2013-2015 Gary V. Vaughan

# Specl is free software distributed under the terms of the MIT license;
# it may be used for any purpose, including commercial purposes, at
# absolutely no cost without having to ask permission.
#
# The only requirement is that if you do use Specl, then you should give
# credit by including the appropriate copyright notice somewhere in your
# product or its documentation.
#
# You should have received a copy of the MIT license along with this
# program; see the file LICENSE.  If not, a copy can be downloaded from
# <http://www.opensource.org/licenses/mit-license.html>.


## ------------ ##
## Environment. ##
## ------------ ##

std_path = $(abs_srcdir)/lib/?.lua
LUA_ENV  = LUA_PATH="$(std_path);$(LUA_PATH)"


## ---------- ##
## Bootstrap. ##
## ---------- ##

old_NEWS_hash = d41d8cd98f00b204e9800998ecf8427e

update_copyright_env = \
	UPDATE_COPYRIGHT_HOLDER='Gary V. Vaughan' \
	UPDATE_COPYRIGHT_USE_INTERVALS=1 \
	UPDATE_COPYRIGHT_FORCE=1


## ------------- ##
## Declarations. ##
## ------------- ##

classesdir		= $(docdir)/classes
modulesdir		= $(docdir)/modules

dist_doc_DATA		=
dist_classes_DATA	=
dist_modules_DATA	=

include specs/specs.mk


## ------ ##
## Build. ##
## ------ ##

dist_bin_SCRIPTS += bin/specl

specldir = $(luadir)/specl

dist_specl_DATA =					\
	lib/specl/badargs.lua				\
	lib/specl/color.lua				\
	lib/specl/compat.lua				\
	lib/specl/inprocess.lua				\
	lib/specl/loader.lua				\
	lib/specl/main.lua				\
	lib/specl/matchers.lua				\
	lib/specl/runner.lua				\
	lib/specl/shell.lua				\
	lib/specl/std.lua				\
	lib/specl/util.lua				\
	lib/specl/version.lua				\
	$(NOTHING_ELSE)

formatterdir = $(specldir)/formatter

dist_formatter_DATA =					\
	lib/specl/formatter/progress.lua		\
	lib/specl/formatter/report.lua			\
	lib/specl/formatter/tap.lua			\
	$(NOTHING_ELSE)

man_MANS += doc/specl.1

$(srcdir)/doc/specl.1: $(srcdir)/specl
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;		\
	test -d "$$d" || $(MKDIR_P) "$$d"
## Exit gracefully if specl.1 is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  $(HELP2MAN)					\
	    '--output=$@'				\
	    '--no-info'					\
	    '--name=Specl'				\
	    $(srcdir)/specl;				\
	fi

## Use a builtin rockspec build with root at $(srcdir)/lib.
mkrockspecs_args = --module-dir $(srcdir)/lib


## -------------- ##
## Documentation. ##
## -------------- ##

dist_doc_DATA +=					\
	$(srcdir)/doc/index.html			\
	$(srcdir)/doc/ldoc.css				\
	$(NOTHING_ELSE)

dist_modules_DATA +=					\
	$(srcdir)/doc/modules/specl.badargs.html	\
	$(srcdir)/doc/modules/specl.inprocess.html	\
	$(srcdir)/doc/modules/specl.matchers.html	\
	$(srcdir)/doc/modules/specl.shell.html		\
	$(NOTHING_ELSE)

allhtml = $(dist_doc_DATA) $(dist_modules_DATA) $(dist_classes_DATA)

$(allhtml): $(dist_specl_DATA)
	test -d $(builddir)/doc || mkdir $(builddir)/doc
if HAVE_LDOC
	$(LDOC) -c build-aux/config.ld -d $(abs_srcdir)/doc .
else
	$(MKDIR_P) doc
	touch doc/index.html doc/ldoc.css
endif

doc: $(allhtml)


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	doc/specl.1					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

DISTCLEANFILES +=					\
	doc/specl.1					\
	$(NOTHING_ELSE)
