## Maintainer-only rules.

dont-forget-to-bootstrap = $(wildcard Makefile)

ifeq ($(dont-forget-to-bootstrap),)

Makefile: Makefile.in
	./configure
	$(MAKE)

Makefile.in:
	./bootstrap --force --verbose --Wall --skip-git

else

include Makefile

GIT ?= git

tag-release:
	$(GIT) diff --exit-code && \
	$(GIT) tag -f -a -m "Release tag" v$(VERSION)

define unpack-distcheck-release
	rm -rf $(PACKAGE)-$(VERSION)/ && \
	tar zxf $(PACKAGE)-$(VERSION).tar.gz && \
	cp -a -f $(PACKAGE)-$(VERSION)/* . &&
	rm -rf $(PACKAGE)-$(VERSION)/ && \
	echo "unpacked $(PACKAGE)-$(VERSION).tar.gz over current directory" && \
	echo './configure && make all" && \
	./configure --version && ./configure &&
	$(MAKE) all
endef

check-in-release: distcheck
	current_branch=`$(GIT) symbolic-ref HEAD`; \
	{ $(GIT) checkout -b release 2>/dev/null || $(GIT) checkout release; } && \
	{ $(GIT) pull origin release || true; } && \
	$(unpack-distcheck-release) && \
	$(GIT) add . && \
	$(GIT) commit -m "Release v$(VERSION)" && \
	$(GIT) tag -a -m "Full source release tag" release-v$(VERSION); \
	$(GIT) checkout `echo "$$current_branch" | sed 's,.*/,,g'


## To test the release process without publishing upstream, use:
##   make release WOGER=: GIT_PUBLISH=:
GIT_PUBLISH ?= $(GIT)
WOGER ?= woger

release:
	$(MAKE) tag-release && \
	$(MAKE) check-in-release && \
	$(GIT_PUBLISH) push && $(GIT_PUBLISH) push --tags && \
	$(WOGER) lua package=$(PACKAGE) \
	    package_name=$(PACKAGE_NAME) \
	    version=$(VERSION) \
	    description="" \
	    notes=docs/RELEASE-NOTES-$(VERSION) \
	    home="http://github.com/gvvaughan/specl"

endif
