## maintainer rules.

# If the user runs GNU make but didn't ./configure yet, do it for them.
dont-forget-to-bootstrap = $(wildcard Makefile)

ifeq ($(dont-forget-to-bootstrap),)

Makefile: Makefile.in
	./configure
	$(MAKE)

Makefile.in:
	./bootstrap

else

# Make tar archive easier to reproduce.
export TAR_OPTIONS = --owner=0 --group=0 --numeric-owner


## --------------- ##
## GNU Make magic. ##
## --------------- ##

# Helper variables.
_empty =
_sp = $(_empty) $(_empty)

# member-check,VARIABLE,VALID-VALUES
# ----------------------------------
# Check that $(VARIABLE) is in the space-separated list of VALID-VALUES, and
# return it.  Die otherwise.
member-check =								\
  $(strip								\
    $(if $($(1)),							\
      $(if $(findstring $(_sp),$($(1))),				\
          $(error invalid $(1): '$($(1))', expected $(2)),		\
          $(or $(findstring $(_sp)$($(1))$(_sp),$(_sp)$(2)$(_sp)),	\
            $(error invalid $(1): '$($(1))', expected $(2)))),		\
      $(error $(1) undefined)))

include Makefile

# Per-project overrides - if any.
-include $(srcdir)/cfg.mk


## --------- ##
## Defaults. ##
## --------- ##

GIT	?= git
LUA	?= lua
TAR	?= tar
WOGER	?= woger

# Override this in cfg.mk if you are using a different format in your
# NEWS file.
today		   ?= $(shell date +%Y-%m-%d)

_build-aux         ?= build-aux
prev_version_file  ?= $(srcdir)/.prev-version

PREV_VERSION        = $(shell cat $(prev_version_file) 2>/dev/null)
VERSION_REGEXP      = $(subst .,\.,$(VERSION))
PREV_VERSION_REGEXP = $(subst .,\.,$(PREV_VERSION))



## ------ ##
## Specl. ##
## ------ ##

# Use 'make check V=1' for verbose output, or set SPECL_OPTS to
# pass alternative options to specl command.

SPECL_OPTS     ?= $(specl_verbose_$(V))
specl_verbose_  = $(specl_verbose_$(AM_DEFAULT_VERBOSITY))
specl_verbose_0 =
specl_verbose_1 = --verbose --formatter=report


## -------- ##
## Release. ##
## -------- ##

# The vast majority of what follows is preparation -in the form
# of early bail-out if something is not right yet- for the final
# check-in-release-branch rule that makes the tip of the release
# branch match the contents of a 'make distcheck' tarball.

# Validate and return $(RELEASE_TYPE), or die.
RELEASE_TYPES = alpha beta stable
release-type = $(call member-check,RELEASE_TYPE,$(RELEASE_TYPES))

WOGER_ENV	 = LUA_INIT= LUA_PATH='$(abs_srcdir)/?-git-1.rockspec'
WOGER_OUT	 = $(WOGER_ENV) $(LUA) -l$(PACKAGE) -e

# This will actually make the release, including sending release
# announcements with 'woger', and pushing changes back to the origin.
# Use it like this, eg:
#				make RELEASE_TYPE=beta
.PHONY: release
release:
	$(AM_V_GEN)$(MAKE) $(release-type)
	$(AM_V_at)$(GIT) push origin master
	$(AM_V_at)$(GIT) push origin release
	$(AM_V_at)$(GIT) push origin v$(VERSION)
	$(AM_V_at)$(GIT) push origin release-v$(VERSION)
	$(AM_V_at)$(WOGER) lua						\
	  package=$(PACKAGE)						\
	  package_name=$(PACKAGE_NAME)					\
	  version=$(VERSION)						\
	  notes=docs/RELEASE-NOTES-$(VERSION)				\
	  home="`$(WOGER_OUT) 'print (description.homepage)'`"		\
	  description="`$(WOGER_OUT) 'print (description.summary)'`"

# These targets do all the file shuffling necessary for a release, but
# purely locally, so you can rewind and redo before pushing anything
# to origin or sending release announcements. Use it like this, eg:
#
#				make beta
.PHONY: alpha beta stable
alpha beta stable:
	$(AM_V_GEN)test $@ = stable &&					\
	  { echo $(VERSION) |$(EGREP) '^[0-9]+(\.[0-9]+)*$$' >/dev/null	\
	    || { echo "invalid version string: $(VERSION)" 1>&2; exit 1;};}\
	  || :
	$(AM_V_at)$(MAKE) vc-diff-check
	$(AM_V_at)$(MAKE) news-check
	$(AM_V_at)$(MAKE) distcheck
	$(AM_V_at)$(MAKE) check
	$(AM_V_at)$(MAKE) release-commit RELEASE_TYPE=$@
	$(AM_V_at)$(MAKE) check-in-release-branch

# Abort the release if there are unchecked in changes remaining.
vc-diff-check:
	$(AM_V_at)if ! $(GIT) diff --exit-code; then		\
	  $(GIT) diff >/dev/null;				\
	  echo "error: Some files are locally modified" >&2;	\
	  rm vc-diffs;						\
	  exit 1;						\
	fi

# Select which lines of NEWS are searched for $(news-check-regexp).
# This is a sed line number spec.  The default says that we search
# only line 3 of NEWS for $(news-check-regexp), to match the behaviour
# of '$(_build-aux)/do-release-commit-and-tag'.
# If you want to search only lines 1-10, use "1,10".
news-check-lines-spec ?= 3
news-check-regexp ?= '^\*.* $(VERSION_REGEXP) \($(today)\)'

news-check: NEWS
	$(AM_V_GEN)if $(SED) -n $(news-check-lines-spec)p $<		\
	    | $(EGREP) $(news-check-regexp) >/dev/null; then		\
	  :;								\
	else								\
	  echo 'NEWS: $$(news-check-regexp) failed to match' 1>&2;	\
	  exit 1;							\
	fi

.PHONY: release-commit
release-commit:
	$(AM_V_GEN)cd $(srcdir)						\
	  && $(_build-aux)/do-release-commit-and-tag			\
	       -C $(abs_builddir) $(VERSION) $(RELEASE_TYPE)


branch		 = $(shell $(GIT) branch |$(SED) -ne '/^\* /{s///;p;q;}')
GCO		 = $(GIT) checkout
pkgver		 = $(PACKAGE)-$(VERSION)
release-tarball	 = $(pkgver).tar.gz

# Anything in $(_save-files) is not removed after switching to the
# release branch, and is thus "in the release". Add addtional partial
# filenames to save in save_release_files, for example:
#    save_release_files = RELEASE-NOTES-
_save-files =						\
		.travis.yml				\
		$(release-tarball)			\
		$(save_release_files)			\
		$(NOTHING_ELSE)


list-to-rexp     = $(SED) -e 's|^|(|' -e 's/|$$/)/'
git-clean-files  = `printf -- '-e %s ' $(_save-files)`
grep-clean-files = `printf -- '%s|' $(_save-files) |$(list-to-rexp)`

# Switch to (or create) 'release' branch, remove all files, except the
# newly generated dist tarball (and .travis.yml, because travis expects
# that file on all active branches), then unpack the dist tarball and
# check in all the files it creates, and tag that as the next release.
# Github creates automatic zipballs of tagged git revisions, so we can
# safely use this tag in the rockspecs we distribute.
.PHONY: check-in-release-branch
check-in-release-branch:
	$(AM_V_GEN)$(GCO) -b release 2>/dev/null || $(GCO) release
	$(AM_V_at)$(GIT) pull origin release || true
	$(AM_V_at)$(GIT) clean -dfx $(git-clean-files)
	$(AM_V_at)remove_re=$(grep-clean-files);			\
	    $(GIT) rm -f `$(GIT) ls-files |$(EGREP) -v "$$remove_re"`
	$(AM_V_at)ln -s . '$(pkgver)'
	$(AM_V_at)$(TAR) zxf '$(release-tarball)'
	$(AM_V_at)rm -f '$(pkgver)' '$(release-tarball)'
	$(AM_V_at)$(GIT) add .
	$(AM_V_at)$(GIT) commit -a -m "Release v$(VERSION)"
	${AM_V_at)$(GIT) tag -s -a -m "Full source release tag" release-v$(VERSION)
	$(AM_V_at)$(GCO) $(branch)

endif
