dnl configure.ac
dnl
dnl Copyright (c) 2013 Free Software Foundation, Inc.
dnl Written by Gary V. Vaughan, 2013
dnl
dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published
dnl by the Free Software Foundation; either version 3, or (at your
dnl option) any later version.
dnl
dnl This program is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this program.  If not, see <http://www.gnu.org/licenses/>.

AC_PREREQ([2.68])

dnl Initialise autoconf and automake
AC_INIT([Specl], [8], [http://github.com/gvvaughan/specl/issues])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])

AS_BOX([Configuring AC_PACKAGE_TARNAME AC_PACKAGE_VERSION])
echo

AM_INIT_AUTOMAKE([-Wall])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

dnl Check for programs
AC_PATH_PROG([HELP2MAN], [help2man], [false])
AC_PATH_PROG([SPECL], [specl], [false])
AX_PROG_LUA([5.1], [5.3])
AC_PROG_EGREP
AC_PROG_SED

dnl Generate output files
SS_CONFIG_TRAVIS
AC_CONFIG_FILES([bin/specl:lib/specl.in], [chmod 555 bin/specl])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
