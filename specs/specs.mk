# Specl make rules.
# Written by Gary V. Vaughan, 2013
#
# Copyright (c) 2013-2015 Gary V. Vaughan

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


## ------ ##
## Specs. ##
## ------ ##

SPECL     = $(top_builddir)/specl
SPECL_ENV += SPECL=$(SPECL)

specl_SPECS =						\
	$(srcdir)/specs/badargs_spec.yaml		\
	$(srcdir)/specs/environment_spec.yaml		\
	$(srcdir)/specs/custom_formatters_spec.yaml	\
	$(srcdir)/specs/formatter/progress_spec.yaml	\
	$(srcdir)/specs/formatter/report_spec.yaml	\
	$(srcdir)/specs/inprocess_spec.yaml		\
	$(srcdir)/specs/loader_spec.yaml		\
	$(srcdir)/specs/matchers_spec.yaml		\
	$(srcdir)/specs/runner_spec.yaml		\
	$(srcdir)/specs/shell_spec.yaml			\
	$(srcdir)/specs/should_spec.yaml		\
	$(srcdir)/specs/specl_spec.yaml			\
	$(NOTHING_ELSE)

EXTRA_DIST +=						\
	$(srcdir)/specs/spec_helper.lua			\
	$(srcdir)/specs/formatter/spec_helper.lua	\
	$(NOTHING_ELSE)

specl-check-local: $(SPECL)

include build-aux/specl.mk
