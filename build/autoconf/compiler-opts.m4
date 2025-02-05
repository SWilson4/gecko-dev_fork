dnl This Source Code Form is subject to the terms of the Mozilla Public
dnl License, v. 2.0. If a copy of the MPL was not distributed with this
dnl file, You can obtain one at http://mozilla.org/MPL/2.0/.

dnl Add compiler specific options

dnl A high level macro for selecting compiler options.
AC_DEFUN([MOZ_COMPILER_OPTS],
[
dnl ========================================================
dnl = Detect static linkage of libstdc++
dnl ========================================================

if test "$OS_TARGET" = Linux; then

AC_CACHE_CHECK([whether we're trying to statically link with libstdc++],
    moz_cv_opt_static_libstdcxx,
    [moz_cv_opt_static_libstdcxx=no
     AC_LANG_SAVE
     AC_LANG_CPLUSPLUS
     cat > conftest.$ac_ext <<EOF
#include <iostream>
int main() { std::cout << 1; }
EOF
     dnl This test is quite conservative: it assumes dynamic linkage if the compilation step fails or if
     dnl the binary format is not supported. But it still detects basic issues.
     if AC_TRY_EVAL([ac_link]) && test -s conftest${ac_exeext} && $LLVM_OBJDUMP --private-headers conftest${ac_exeext} 2> conftest.err 1> conftest.out
     then
         if test -s conftest.err
         then :
         elif grep -q -E 'NEEDED.*lib(std)?c\+\+' conftest.out
         then :
         else moz_cv_opt_static_libstdcxx=yes
         fi
     fi
     AC_LANG_RESTORE
     rm -f conftest*
])
if test "$moz_cv_opt_static_libstdcxx" = "yes"; then
    AC_MSG_ERROR([Firefox does not support linking statically with libstdc++])
fi

fi

dnl ========================================================
dnl = Automatically remove dead symbols
dnl ========================================================

if test "$CC_TYPE" != clang-cl -a "$GCC_USE_GNU_LD" -a -z "$DEVELOPER_OPTIONS" -a -z "$MOZ_PROFILE_GENERATE" -a -z "$SANCOV"; then
    if test -n "$MOZ_DEBUG_FLAGS"; then
        dnl See bug 670659
        AC_CACHE_CHECK([whether removing dead symbols breaks debugging],
            moz_cv_opt_gc_sections_breaks_debug_ranges,
            [echo 'int foo() {return 42;}' \
                  'int bar() {return 1;}' \
                  'int main() {return foo();}' > conftest.${ac_ext}
            if AC_TRY_COMMAND([${CC-cc} -o conftest.${ac_objext} $CFLAGS $MOZ_DEBUG_FLAGS -c conftest.${ac_ext} 1>&2]) &&
                AC_TRY_COMMAND([${CC-cc} -o conftest${ac_exeext} $LDFLAGS $MOZ_DEBUG_FLAGS -Wl,--gc-sections conftest.${ac_objext} $LIBS 1>&2]) &&
                test -s conftest${ac_exeext} -a -s conftest.${ac_objext}; then
                 if test "`$PYTHON3 -m mozbuild.configure.check_debug_ranges conftest.${ac_objext} conftest.${ac_ext}`" = \
                         "`$PYTHON3 -m mozbuild.configure.check_debug_ranges conftest${ac_exeext} conftest.${ac_ext}`"; then
                     moz_cv_opt_gc_sections_breaks_debug_ranges=no
                 else
                     moz_cv_opt_gc_sections_breaks_debug_ranges=yes
                 fi
             else
                  dnl We really don't expect to get here, but just in case
                  moz_cv_opt_gc_sections_breaks_debug_ranges="no, but it's broken in some other way"
             fi
             rm -rf conftest*])
         if test "$moz_cv_opt_gc_sections_breaks_debug_ranges" = no; then
             DSO_LDOPTS="$DSO_LDOPTS -Wl,--gc-sections"
         fi
    else
        DSO_LDOPTS="$DSO_LDOPTS -Wl,--gc-sections"
    fi
fi

if test "$CC_TYPE" != clang-cl ; then
    case "${OS_TARGET}" in
    Darwin|WASI)
        # It's the default on those targets, and clang complains about -pie
        # being unused if passed.
        ;;
    *)
        MOZ_PROGRAM_LDFLAGS="$MOZ_PROGRAM_LDFLAGS -pie"
        ;;
    esac
fi

AC_SUBST(MOZ_PROGRAM_LDFLAGS)


])
