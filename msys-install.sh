#!/bin/sh
# Install script that works without Make
# (Written because git-bash doesn't come with that tool.)
# Must track Makefile :-(

if test -d /cygdrive/c
then
  PREFIX=/cygdrive/c/opt/oblong
else
  PREFIX=/c/opt/oblong
fi

# This is version major * 1000 + version minor
# Must edit VERSIONOID in both Makefile and msys-install.sh
VERSIONOID=1044

# bau: bau.in
echo VERSIONOID is ${VERSIONOID}
sed "s/@VERSIONOID@/${VERSIONOID}/" < bau.in > bau
chmod +x bau
sed "s/@VERSIONOID@/${VERSIONOID}/" < obs.in > obs
chmod +x obs

# install-bau: bau
install -m 755 -d ${DESTDIR}${PREFIX}/bin
install -m 755 bau ${DESTDIR}${PREFIX}/bin
install -m 755 bau.cmd ${DESTDIR}${PREFIX}/bin
install -m 755 ob-coverage.sh ${DESTDIR}${PREFIX}/bin
install -m 755 uberbau ${DESTDIR}${PREFIX}/bin
install -m 755 -d ${DESTDIR}${PREFIX}/share/man/man1
#install -m 644 bau.1 ${DESTDIR}${PREFIX}/share/man/man1/bau.1
# fixme: should install bau-defaults to share, but that's awkward for now
install -m 755 -d ${DESTDIR}${PREFIX}/bin/bau-defaults
install -m 644 bau-defaults/buildshim-ubu ${DESTDIR}${PREFIX}/bin/bau-defaults/buildshim-ubu
install -m 644 bau-defaults/buildshim-osx ${DESTDIR}${PREFIX}/bin/bau-defaults/buildshim-osx
install -m 644 bau-defaults/buildshim-win ${DESTDIR}${PREFIX}/bin/bau-defaults/buildshim-win
install -m 644 bs_funcs.sh ${DESTDIR}${PREFIX}/bin

# install-obs: obs
install -m 755 -d ${DESTDIR}${PREFIX}/bin
install -m 644 obs_funcs.sh ${DESTDIR}${PREFIX}/bin
install -m 755 ob-set-defaults ${DESTDIR}${PREFIX}/bin
install -m 755 ob-set-targets ${DESTDIR}${PREFIX}/bin
install -m 755 obs ob-remove.sh ${DESTDIR}${PREFIX}/bin
install -m 755 obs.cmd ${DESTDIR}${PREFIX}/bin
install -m 755 ob-list-dbg-pkgs ${DESTDIR}${PREFIX}/bin
install -m 755 licensing/ob-list-licenses ${DESTDIR}${PREFIX}/bin
install -m 755 licensing/ob-filter-licenses ${DESTDIR}${PREFIX}/bin
install -m 755 licensing/ob-parse-licenses ${DESTDIR}${PREFIX}/bin
install -m 755 ob-build-deps ${DESTDIR}${PREFIX}/bin
