#  Behaviour Driven Development for Lua 5.1, 5.2, 5.3 & 5.4
#  Copyright (C) 2013-2016, 2108 Gary V. Vaughan

HELP2MAN = help2man
LUA	 = lua
SED	 = sed
SPECL	 = bin/specl

VERSION	= 14.1.8

luadir	= lib/specl
SOURCES =					\
	$(luadir)/badargs.lua			\
	$(luadir)/color.lua			\
	$(luadir)/compat.lua			\
	$(luadir)/formatter/progress.lua	\
	$(luadir)/formatter/report.lua		\
	$(luadir)/formatter/tap.lua		\
	$(luadir)/inprocess.lua			\
	$(luadir)/loader.lua			\
	$(luadir)/main.lua			\
	$(luadir)/matchers.lua			\
	$(luadir)/runner.lua			\
	$(luadir)/shell.lua			\
	$(luadir)/std.lua			\
	$(luadir)/util.lua			\
	$(luadir)/version.lua			\
	$(NOTHING_ELSE)


all: $(luadir)/version.lua


$(luadir)/version.lua: $(luadir)/version.lua.in .FORCE
	$(SED)										\
		-e 's,@PACKAGE_NAME@,Specl,g'						\
		-e 's,@PACKAGE_BUGREPORT@,http://github.com/gvvaughan/specl/issues,g'	\
		-e 's,@VERSION@,$(VERSION),g'						\
		'$<' > '$@T';
	cmp -s '$@' '$@T' && rm -f '$@T' || mv '$@T' '$@'

doc: $(SOURCES)
	$(HELP2MAN) -c build-aux/config.ld .


CHECK_ENV = 								\
	LUA=$(LUA)							\
	LUA_PATH="`pwd`/lib/?/init.lua;`pwd`/lib/?.lua;$${LUA_PATH-;}"	\
	LUA_CPATH="`pwd`/lib/?.dylib;`pwd`/lib/?.so;$${LUA_CPATH-;}"	\
	$(NOTHING_ELSE)

check: $(SOURCES)
	$(CHECK_ENV) $(SPECL) $(SPECL_OPTS) spec/*_spec.yaml


.FORCE:
