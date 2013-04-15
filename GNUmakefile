## maintainer rules.

dont-forget-to-bootstrap = $(wildcard Makefile)

ifeq ($(dont-forget-to-bootstrap),)

Makefile: Makefile.in
	./configure
	$(MAKE)

Makefile.in:
	./bootstrap

else

# Use 'make check V=1' for verbose output, or set SPECL_OPTS to
# pass alternative options to specl command.
SPECL_OPTS ?= $(specl_verbose_$(V))
specl_verbose_ = $(specl_verbose_$(AM_DEFAULT_VERBOSITY))
specl_verbose_0 =
specl_verbose_1 = --verbose --formatter=report

include Makefile

MKROCKSPECS = $(LUA) $(srcdir)/build-aux/mkrockspecs
ROCKSPEC_TEMPLATE = $(srcdir)/rockspecs.lua

LUA_BINDIR ?= $(shell which $(LUA) |sed 's|/[^/]*$$||')
LUA_INCDIR ?= `cd $(LUA_BINDIR)/../include && pwd`
LUA_LIBDIR ?= `cd $(LUA_BINDIR)/../lib && pwd`

luarocks-config.lua: GNUmakefile
	$(AM_V_GEN){						\
	  echo 'rocks_trees = { "$(abs_srcdir)/luarocks" }';	\
	  echo 'variables = {';					\
	  echo '  LUA = "$(LUA)",';				\
	  echo '  LUA_BINDIR = "$(LUA_BINDIR)",';		\
	  echo '  LUA_INCDIR = "'$(LUA_INCDIR)'",';		\
	  echo '  LUA_LIBDIR = "'$(LUA_LIBDIR)'",';		\
	  echo '}';						\
	} > '$@'

rockspecs: luarocks-config.lua $(srcdir)/build-aux/mkrockspecs $(ROCKSPEC_TEMPLATE)
	$(AM_V_at)rm -f *.rockspec
	@echo "  GEN      $(PACKAGE)-$(VERSION)-1.rockspec"
	$(AM_V_at)$(MKROCKSPECS) $(PACKAGE) $(VERSION) $(ROCKSPEC_TEMPLATE)
	@echo "  GEN      $(PACKAGE)-git-1.rockspec"
	$(AM_V_at)$(MKROCKSPECS) $(PACKAGE) git $(ROCKSPEC_TEMPLATE)


## -------- ##
## Release. ##
## -------- ##

## To test the release process without publishing upstream, use:
##   make release WOGER=: GIT_PUBLISH=:
GIT		?= git
GIT_PUBLISH	?= $(GIT)
WOGER		?= woger

WOGER_ENV	 = LUA_INIT= LUA_PATH='$(abs_srcdir)/?-git-1.rockspec'
WOGER_OUT	 = $(WOGER_ENV) $(LUA) -l$(PACKAGE) -e

pkgver		 = $(PACKAGE)-$(VERSION)
release-tarball	 = $(pkgver).tar.gz

# Anything in $(_save-files) is not removed after switching to the
# release branch, and is thus "in the release". For example:
#     save_release_files = |RELEASE-NOTES-
_save-files = (.travis.yml|$(tarball)$(save_release_files))

git-clean-files = $(GIT) ls-files |grep -E -v '$(_save-files)'

define unpack-distcheck-release
	$(GIT) clean -dfx -e '$(release-tarball)' &&			\
	rm -f `$(git-unreleased-files)` &&				\
	ln -s . '$(pkgver)' &&						\
	tar zxf '$(release-tarball)' &&					\
	rm -f '$(pkgver)' '$(release-tarball)' &&			\
	echo "unpacked $(release-tarball) into release branch" &&	\
	$(GIT) add .
endef

tag-release:
	$(GIT) diff --exit-code &&					\
	$(GIT) tag -f -a -m "Release tag" v$(VERSION)

check-in-release: distcheck
	current_branch=`$(GIT) symbolic-ref HEAD`;			\
	{ $(GIT) checkout -b release 2>/dev/null || $(GIT) checkout release; } && \
	{ $(GIT) pull origin release || true; } &&			\
	$(unpack-distcheck-release) &&					\
	$(GIT) commit -a -m "Release v$(VERSION)" &&			\
	$(GIT_PUBLISH) push &&						\
	$(GIT) tag -f -a -m "Full source release tag" release-v$(VERSION); \
	$(GIT) checkout `echo "$$current_branch" | sed 's,.*/,,g'`

release:
	$(MAKE) tag-release &&						\
	$(MAKE) check-in-release &&					\
	$(GIT_PUBLISH) push && $(GIT_PUBLISH) push --tags &&		\
	$(WOGER) lua							\
	  package=$(PACKAGE)						\
	  package_name=$(PACKAGE_NAME)					\
	  version=$(VERSION)						\
	  notes=docs/RELEASE-NOTES-$(VERSION)				\
	  home="`$(WOGER_OUT) 'print (description.homepage)'`"		\
	  description="`$(WOGER_OUT) 'print (description.summary)'`"

endif
