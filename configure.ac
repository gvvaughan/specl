dnl configure.ac
dnl Written by Gary V. Vaughan, 2013
dnl
dnl Copyright (c) 2013-2016 Gary V. Vaughan
dnl
dnl Specl is free software distributed under the terms of the MIT license;
dnl it may be used for any purpose, including commercial purposes, at
dnl absolutely no cost without having to ask permission.
dnl
dnl The only requirement is that if you do use Specl, then you should give
dnl credit by including the appropriate copyright notice somewhere in your
dnl product or its documentation.
dnl
dnl You should have received a copy of the MIT license along with this
dnl program; see the file LICENSE.  If not, a copy can be downloaded from
dnl <http://www.opensource.org/licenses/mit-license.html>.

AC_PREREQ([2.68])

dnl Initialise autoconf and automake
AC_INIT([Specl], [15.0.0], [http://github.com/gvvaughan/specl/issues])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])

AS_BOX([Configuring AC_PACKAGE_TARNAME AC_PACKAGE_VERSION])
echo

AM_INIT_AUTOMAKE([-Wall foreign])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

dnl Check for programs
AC_PROG_EGREP
AC_PROG_SED
AC_PATH_PROG([HELP2MAN], [help2man], [false])
AX_PROG_LUA([5.1], [5.4])
AC_PATH_PROG([SPECL], [specl], [false])
AC_PATH_PROG([LUAM], [luam], [false])

AC_PATH_PROG([LDOC], [ldoc], [false])
AM_CONDITIONAL([HAVE_LDOC], [test false != "$LDOC"])

dnl Generate output files
AC_CONFIG_FILES([Makefile build-aux/config.ld])
AC_CONFIG_FILES([specl], [chmod 555 specl])
AC_CONFIG_FILES([lib/specl/version.lua], [chmod 444 lib/specl/version.lua])
AC_OUTPUT
