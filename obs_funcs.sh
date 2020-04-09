# (C) 2014,2015,2015,2016,2017,2018 Oblong
# No shebang because this is not executed, it is included.
# Shell functions used in oblong build scripts
# Shipped along with platform, so can be used in customer-facing samples
# NOTE: out of date versions of this package can be very confusing indeed to developers

# Print an error message and terminate with nonzero status.
bs_abort() {
    echo "fatal error: $*"
    exit 1
}

# Print a warning message
bs_warn() {
    echo "warning: $*"
}

# Given a g-speak version number, output the major version of yobuild it uses.
bs_yovo2yoversion() {
    case $1 in
    2*|3.[0-9]|3.[0-9].*|3.1[01]*)
        # Errors to stderr since callers always redirect stdout to a variable
        bs_abort "unsupported yovo version $1" >&2
        ;;
    3.12*)
        echo 8
        ;;
    3.1[3456]*)
        echo 9
        ;;
    3.1[789]*|3.2[012]*)
        echo 10
        ;;
    3.*|4.0|4.0.*)
        echo 11
        ;;
    4.[0-8])
        echo 12
        ;;
    4.9|5.*)
        echo 13
        ;;
    *)
        # Errors to stderr since callers always redirect stdout to a variable
        bs_abort "unsupported yovo version $1" >&2
        ;;
    esac
}

# Given a g-speak version number, output the cef suffix common to the
# oblong-yobuildNN-cef and oblong-webthing packages it is usually bundled with.
# (You can pick a different CEF if you really want to, though.)
bs_yovo2cefversion() {
    case $1 in
    3.8|3.10|3.12|3.14|3.16|3.18) echo cef;;
    3.20) echo cef2272;;
    3.2[1-4]) echo cef2526;;
    3.2[5-9]|3.3[0-9])
        # bleah.  cef2704 does not build on ubu1204, yet we must still support 1204 for a bit.
        case $_os in
        ubu1204) echo cef2526;;
        *)       echo cef2704;;
        esac
        ;;
    4.0) echo cef2704;;
    4.1|4.2) echo cef3202;;
    4.3|4.4) echo cef3239;;
    4.5|4.6) echo cef3282;;
    4.*|5.*) echo cef3497;;
    *) bs_abort "bs_yovo2cefversion: don't know which CEF goes with g-speak $1" >&2;;
    esac
}

# Echo a short code for the operating system / version.
# e.g. osx107, osx109, ubu1004, ubu1204, ubu1404, or cygwin
# FIXME: should probably be win7 or win8 rather than cygwin

bs_detect_os() {
    if test "$BS_FORCE_OS"
    then
        printf %s "$BS_FORCE_OS"
        return
    fi
    # Detect OS
    case "$(uname -s)" in
    Linux)
        if grep -q "Ubuntu 10.04" /etc/issue ; then echo ubu1004
        elif grep -q "Ubuntu 12.04" /etc/issue ; then echo ubu1204
        elif grep -q "Ubuntu 14.04" /etc/issue ; then echo ubu1404
        elif grep -q "Ubuntu 16.04" /etc/issue ; then echo ubu1604
        elif grep -q "Ubuntu Core 16" /etc/issue ; then echo ubu1604
        elif grep -q "Ubuntu 18.04" /etc/issue ; then echo ubu1804
        elif grep -q "Ubuntu 19.04" /etc/issue ; then echo ubu1904
        elif grep -q "Ubuntu 19.10" /etc/issue ; then echo ubu1910
        else bs_abort "unrecognized linux" >&2
        fi
        ;;
    Darwin)
        macver=$(sw_vers -productVersion)
        case "$macver" in
        # we pretend everything 10.7 or later is osx107 for now
        # Except that OS X 10.9 has a different Ruby ABI,
        # and we've decided to use XCode 4 on 10.7/10.8 vs.
        # XCode 5 on 10.9, so osx107 vs. osx109 here implies libstdc++ vs. libc++.
        10.15|10.15.*) echo osx1015;;
        10.14|10.14.*) echo osx1014;;
        10.13|10.13.*) echo osx1013;;
        10.12|10.12.*) echo osx1012;;
        10.11|10.11.*) echo osx1011;;
        10.10|10.10.*) echo osx1010;;
        10.9|10.9.*) echo osx109;;
        10.8|10.8.*) echo osx107;;
        10.7|10.7.*) echo osx107;;
        10.6|10.6.*) echo osx106;;
        *) bs_abort "unrecognized mac '$macver'" >&2 ;;
        esac
        ;;
    CYGWIN*WOW64) echo cygwin;;
    CYGWIN*)      echo cygwin;;
    MINGW*)       echo mingw;;
    *) bs_abort "unrecognized os" >&2 ;;
    esac
}

# Default MASTER depends on current OS; that way we can
# do a gradual transition to a new MASTER, newest OS's first.
bs_default_master() {
    case $_os in
    "")              bs_abort "bs_default_master: _os not set" >&2;;
    *)               echo buildhost5.oblong.com;;
    esac
}

# Echo the number of CPU cores
bs_detect_ncores() {
    case $_os in
    ubu*)
        grep -c processor /proc/cpuinfo || echo 1
        ;;
    osx*)
        system_profiler -detailLevel full SPHardwareDataType | awk '/Total Number .f Cores/ {print $5};'
        ;;
    cygwin|mingw)
        echo "$NUMBER_OF_PROCESSORS"
        ;;
    esac
}

# Only used on Windows
bs_detect_toolchain()
{
    if test -d "$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community"
    then
        echo msvc2017
    elif test -d "$DRIVEC/Program Files (x86)/Microsoft Visual Studio 14.0"
    then
        echo msvc2015
    elif test -d "$DRIVEC/Program Files (x86)/Microsoft Visual Studio 12.0"
    then
        echo msvc2013
    elif test -d "$DRIVEC/Program Files (x86)/Microsoft Visual Studio 10.0"
    then
        echo msvc2010
    else
        bs_abort "None of Visual Studio 2017 Community, 2015, 2013, nor 2010 detected" >&2
    fi
}

# Look at source tree to see what version of cef this project builds against currently
# Returns same kinds of values as bs_yovo2cefversion
bs_get_cef_version() {
    egrep 'webthing2?-cef' "${bs_origdirslash}debian/control" 2>/dev/null | sed -E 's/.*webthing2?-cef/cef/;s/-.*//;s/,.*//' | head -n1
}

# Look at source tree to see what version of g-speak this project builds against currently
bs_get_gspeak_version() {
    # Allow -gh suffix after g-speak or gs (it means "greenhouse free")
    # sed's regular expressions are a bit ugly
    #  egrep: (abc)?
    #  sed:   \(abc\)\{0,1\}
    if test -f "${bs_origdirslash}debian/control" && egrep -q 'g-speak(-gh)?[0-9]' "${bs_origdirslash}debian/control"
    then
        egrep 'g-speak(-gh)?[0-9]' "${bs_origdirslash}debian/control" | head -n 1 | sed 's/.*g-speak\(-gh\)\{0,1\}//;s/[^0-9.].*//'
    elif test -f "${bs_origdirslash}debian/control" && egrep -q 'gs(-gh)?[0-9.]+x' "${bs_origdirslash}debian/control"
    then
        egrep 'gs(-gh)?[0-9.]+x' "${bs_origdirslash}debian/control" | head -n 1 | sed 's/^.*gs\(-gh\)\{0,1\}\([1-9][0-9.]*\)x.*$/\2/'
    elif test -f "${bs_origdirslash}debian/control" && egrep -q -e '-gs[0-9.]+' "${bs_origdirslash}debian/control"
    then
        egrep -e '-gs[0-9.]+' "${bs_origdirslash}debian/control" | head -n 1 | sed 's/^.*gs\([1-9][0-9.]*\)[^0-9.].*$/\1/'
    elif test -f "${bs_origdirslash}debian/control" && egrep -q 'oblong-plasma-ruby' "${bs_origdirslash}debian/control"
    then
        egrep 'oblong-plasma-ruby' "${bs_origdirslash}debian/control" | sed 's/.*ruby//;s/,.*//'
    elif test -f bs-options.dat && grep -q g-speak bs-options.dat
    then
        # ob-set-defaults leaves this behind.  Useful for non-g-speak projects trickling down to g-speak projects.
        grep g-speak bs-options.dat | sed 's/.*--g-speak //;s/ .*//'
    elif test -f "${bs_origdirslash}debian/rules" && egrep -q '^G_SPEAK_HOME=' "${bs_origdirslash}debian/rules"
    then
        awk -F= '/G_SPEAK_HOME=/ {print $2}' "${bs_origdirslash}debian/rules" | sed 's/.*speak//'
    else
        bs_warn "bs_get_gspeak_version: cannot find g-speak version" >&2
    fi
}

# Look at source tree to see what g-speak it builds against currently
bs_get_gspeak_home() {
    if test -f "${bs_origdirslash}debian/rules" && egrep -q '^G_SPEAK_HOME=' "${bs_origdirslash}debian/rules"
    then
        awk -F= '/^G_SPEAK_HOME=/ {print $2}' "${bs_origdirslash}debian/rules"
    else
        # Would like to do this:
        #echo /opt/oblong/g-speak$(bs_get_gspeak_version)
        # but that discards error status of the called function... so use printf
        # instead (which by default does not output a newline) so we can concatenate
        # the two strings without losing the exit status from bs_get_gspeak_version.
        printf /opt/oblong/g-speak
        # Annoyingly, some code (e.g. bau-defaults/buildshim-ubu)
        # relies on bs_get_gspeak_version not aborting on error,
        # so just test if it's empty here.  Same code (bs_test_env_setup)
        # wants this function to return empty on failure, sigh.
        local ver
        ver=$(bs_get_gspeak_version)
        case "$ver" in
        "") bs_warn "bs_get_gspeak_home: can't get g-speak version" >&2;;
        *) echo "$ver";;
        esac
    fi
}

# FIXME: Some buildshims (greenhouse) use old name for above function
bs_get_g_speak_home() {
    bs_get_gspeak_home "$@"
}

# See what version of yobuild this project builds against currently
# Optional arg: G_SPEAK_HOME
bs_get_yoversion() {
    local yob=$(bs_get_yobuild_home)
    if echo "$yob" | awk -F- 'BEGIN { err=1 } /deps/ { print $3; err=0 } END { exit err }'
    then
        return 0
    elif ob-version | awk 'BEGIN { err=1 } /yobuild version : [^u]/ { print $4; err=0 } END { exit err }' > /tmp/yover.dat.$$
    then
        sed 's/\..*//' < /tmp/yover.dat.$$
        rm -rf  /tmp/yover.dat.$$
        return 0
    elif test -n "$1"
    then
        # guess based on supplied g-speak version
        bs_yovo2yoversion "$1"
    else
        # guess based on detected g-speak version
        local ver
        ver=$(bs_get_gspeak_version)
        bs_yovo2yoversion "$ver"
    fi
}

# Look at source tree to see what yobuild this project builds against currently
# Optional arg: G_SPEAK_HOME
bs_get_yobuild_home() {
    if test -f "${bs_origdirslash}debian/rules" && egrep -q '^YOBUILD=' "${bs_origdirslash}debian/rules"
    then
        # First try: get from debian/rules
        # FIXME: on Windows, debian/rules in samples is a Windows-style path, kind of, with C: tacked on.  Convert to cygwin.
	# FIXME: no, don't convert to cygwin, strip the drive letter.
	# We don't support building on other drives for now.
        awk -F= '/^YOBUILD=/ {print $2}' "${bs_origdirslash}debian/rules" | sed "s,^C:,,;s,//,/,g" | tr -d '\015'
    elif ob-version | awk 'BEGIN { err=1 } /ob_yobuild_dir/ { print $3; err=0 } END { exit err }'
    then
        # Second try: ask ob-version
        return 0
    elif test -n "$1" && test -f "$1"/lib/pkgconfig/libLoam.pc
    then
        # Third try: look up yobuild used by packages installed at given G_SPEAK_HOME
        # FIXME: bit of a kludge, should have an explicit variable for this in libLoam.pc
        grep 'Cflags:' < "$1"/lib/pkgconfig/libLoam.pc | sed 's,.*-I,,;s,/include.*,,'
    else
        # fourth try: guess based on detected g-speak version
        # Can't use echo, or it will clear status after bs_abort sets it
        # Also, can't nest function calls, have to save intermediaries as variables
        # Also, can't declare and set local variable in same statement, or it ignores status
        printf /opt/oblong/deps-%s- "$(getconf LONG_BIT)"
        local ver
        ver=$(bs_get_gspeak_version)
        bs_yovo2yoversion "$ver"
    fi
}

# Look at source tree to see where this project will be installed
bs_get_prefix() {
    if test -f "${bs_origdirslash}debian/rules" && egrep -q '^PREFIX=' "${bs_origdirslash}debian/rules"
    then
        awk -F= '/^PREFIX=/ {print $2}' "${bs_origdirslash}debian/rules"
    else
        bs_get_gspeak_home
    fi
}

# Get the package name (for use with bs_upload)
bs_get_pkgname() {
    awk 'BEGIN { status=1; }; /Source:/ {print $2; status=0;}; END {exit(status);}' < "${bs_origdirslash}debian/control"
}

# Echo the version number of this project as given by git
# Assumes tags are like rel-3.x or dev-4.5.1, or maybe just 3.x, and returns the first numeric part including dots
# Ignores lightweight tags, i.e. assumes versions are tagged with git -a -m
bs_get_version_git() {
    # FIXME: this is overly complex
    # git describe --long's output looks like
    # tag-COUNT-CHECKSUM
    # or, if at a tag,
    # tag
    if ! d1=$(git describe --long 2> /dev/null)
    then
        # let bau work in samples
        echo "bs_get_version_git: not in a git repo.  Returning version 0.1." >&2
        echo "0.1"
        return
    fi
    # Strip off -CHECKSUM suffix, if any
    case $_os in
    osx*) xregx=-E;;
    *) xregx=-r;;
    esac
    # git uses a variable number of digits in the hex hash ID
    d2=$(echo "$d1" | sed $xregx 's/-g[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]*$//')
    # Strip off -COUNT suffix, if any
    d3=$(echo "$d2" | sed 's/-[0-9]*$//')
    # Remove non-numeric prefix (e.g. rel- or debian/), if any
    d4=$(echo "$d3" | sed 's/^[^0-9]*//')
    # Remove non-numeric suffix (e.g. -mz-gouda), if any
    d5=$(echo "$d4" | sed 's/-[^0-9]*$//')
    case "$d5" in
    "") bs_abort "can't parse version number from git describe --long's output $d1";;
    esac
    echo "$d5"
}

# Echo the major version number of this project as given by git
# Assumes tags are like rel-3.x or dev-4.5.1, or maybe just 3.x, and returns the first numeric part before a dot
# Ignores lightweight tags, i.e. assumes versions are tagged with git -a -m
bs_get_major_version_git() {
    # Remove anything after a dot, then remove anything before a dash
    git describe --long | sed 's/\..*//;s/.*-//'
}

# Echo the minor version number of this project as given by git
# Assumes tags are like rel-3.x or dev-4.5.1, or maybe just 3.x, and returns the numeric part after the first dot
# Ignores lightweight tags, i.e. assumes versions are tagged with git -a -m
bs_get_minor_version_git() {
    git describe --long 2> /dev/null | sed 's/.*\.\([0-9]*\).*/\1/'
}

# Echo the change number since the start of this branch as given by git
bs_get_changenum_git() {
    # git describe --long's output looks like
    # name-COUNT-CHECKSUM
    # First strip off the checksum field, then the name.
    if ! d1=$(git describe --long 2> /dev/null)
    then
        # No releases!  Just count changes since epoch.
        git log --oneline 2> /dev/null | wc -l | sed 's/^[[:space:]]*//'
        return 0
    fi
    d2=$(echo "$d1" | sed 's/-g[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]*$//')
    d3=$(echo "$d2" | sed 's/^.*-//')
    case "$d3" in
    "") bs_abort "can't parse change number from git describe --long's output $d1";;
    esac
    echo "$d3"
}

# Look at source tree to see whether it is built for or against greenhouse
# (i.e. static yovo):
bs_is_greenhouse() {
    grep -q -e '-gh[-0-9]' debian/control
}

# List packages that could be installed by bs_install
bs_pkg_list() {
  case "${MASTER}" in
  "")
      bs_abort "bs_pkg_list: must specify MASTER"
      ;;
  localhost)
      (cd ${bs_install_root}; ls -d */$_os | sed 's,/.*,,')
      ;;
  *)
      ssh -o StrictHostKeyChecking=no -n "$(bs_get_install_sshspec)" "cd ${bs_install_root}; ls -d */$_os | sed 's,/.*,,'"
      ;;
  esac
}

# return highest-versioned entry in given subdirectory of repo, if any
bs_pkg_latest_() {
  case "${MASTER}" in
  localhost)
      (cd "${bs_install_root}/$1" && ls | $sort --version-sort | tail -n 1)
      ;;
  *)
      ssh -o StrictHostKeyChecking=no -n "$(bs_get_install_sshspec)" "cd '${bs_install_root}/$1' && ls | $sort --version-sort | tail -n 1"
      ;;
  esac
}

# Return absolute path to a sort that supports --version-sort on the master
bs_download_get_sort() {
    # Need newest sort for --version-sort.  On Mac, sort is too old and aborts, but gsort exists and is new enough.
    case "${MASTER}" in
    localhost)
        if sort --version-sort /dev/null 2>/dev/null
        then
            which sort
        elif gsort --version-sort /dev/null 2>/dev/null
        then
            which gsort
        else
            echo fail
        fi
        ;;
    *)
        # Same thing remotely; add brew's bin since ssh doesn't have it by default.
        ssh -o StrictHostKeyChecking=no -n "$(bs_get_install_sshspec)" 'PATH="${PATH}":/usr/local/bin:/opt/local/bin; if sort --version-sort /dev/null 2>/dev/null; then which sort; elif gsort --version-sort /dev/null 2>/dev/null; then which gsort; else echo fail; fi'
    esac
}

# Usage: bs_download package ...
# Downloads the latest build of the given packages
bs_download() {
    bs_download_dest=${bs_download_dest:-.}
    case "${MASTER}" in
    "") bs_abort "bs_download: must specify MASTER";;
    esac

    sort=$(bs_download_get_sort)
    case $sort in
    /*) ;;
    *) bs_abort "A sort supporting --version-sort was not found.  Please install gnu sort (coreutils) on $MASTER."
    esac

    for depname
    do
        local xy=$(bs_pkg_latest_ $depname/$_os)

        # BEGIN KLUDGE: during transition to uploading as $(bs_get_pkgname), add in some special cases
        # Once all buildshims updated, remove kludge
        case "$depname" in
          oblong-*)    ;;
          *)
            if test "$xy" = ""
            then
              # Try prefixing dependency name with oblong- (hey, it works with staging...)
              local newname=oblong-$depname
              if xy=$(bs_pkg_latest_ $newname/$_os) && test "$xy" != ""
              then
                bs_warn "bs_download: name $depname deprecated, please use $newname"
                depname=$newname
              fi
            fi
            ;;
        esac
        # END KLUDGE

        case "$xy" in
        "") echo "bs_download: warning: package $depname not yet built for $_os"; return 1;;
        esac

        local micro=$(bs_pkg_latest_ "$depname/$_os/$xy")
        local patch=$(bs_pkg_latest_ "$depname/$_os/$xy/$micro")
        case "${MASTER}" in
        localhost)
             cp "${bs_install_root}/$depname/$_os/$xy/$micro/$patch"/*.tar.*z* "${bs_download_dest}";;
        *)
             scp -o StrictHostKeyChecking=no "$(bs_get_install_sshspec):${bs_install_root}/$depname/$_os/$xy/$micro/$patch/*.tar.*z*" "${bs_download_dest}/";;
        esac
    done
}

# Usage: bs_untar_restricted tarballname
# Simulates the command
#     $SUDO tar -C / -xf $tarball 2>&1
# but disallow installing into anywhere but /usr/local or /opt
# This avoids running afoul of Mac OS X 10.11 errors e.g. creating /usr
bs_untar_restricted() {
    local dest
    local depth
    # Detect destination.  Tarballs often start with the top level directories.
    # Choose the third entry, that should be /x/y/z/  (or /x/y/z/foo, depending on tar version)
    # Handle whacky tarball qwt532.tar.gz whose paths start with ./
    dest="/$(tar -tf "$1" | head -n2 | tail -n1)"
    case "$dest" in
    /usr/local/*) dest="/usr/local"; depth=2;;
    /opt/*) dest="/opt"; depth=1;;
    /./opt/*) dest="/opt"; depth=2;;
    /cygdrive/c/opt/*) dest="$DRIVEC/opt"; depth=3;;   # cygwin
    /cygdrive/c//opt/*) dest="$DRIVEC/opt"; depth=3;;  # --strip-components ignores doubled slashes
    /c/opt/*) dest="$DRIVEC/opt"; depth=2;;       # msys aka git-bash
    *) bs_abort "bs_untar_restricted: illegal destination $dest for tarball $1, only /usr/local and /opt allowed";;
    esac

    # Prepend c: if missing on windows
    # FIXME: be less kludgy
    case "$_os" in
    cygwin|mingw)
        if test "$dest" != "$DRIVEC/opt"
        then
            dest="$DRIVEC$dest"
        fi
    esac

    $SUDO mkdir -p "$dest"
    # -o : don't try to chown
    # -m : don't try to set time (fails on mac sometimes)
    $SUDO tar -m -o --strip-components=$depth -C "$dest" -xf "$1" 2>&1
}

# Usage: bs_install package ...
# Downloads and unpacks the latest build of the given packages
bs_install() {
    bs_download_dest=bs_install.tmp
    rm -rf ${bs_download_dest}
    mkdir ${bs_download_dest}
    bs_download "$@"

    # Remember what's been installed; will be used in bs_deps_hook
    # Except on Ubuntu, where bs_deps_append must be only debian packages.
    case $_os in
    ubu*) ;;
    *)    echo "$@" | bs_deps_append;;
    esac

    # And now the scary part.
    for tarball in bs_install.tmp/*.tar.*z*
    do
        # FIXME: add a postinstall step to e.g. install things into /etc/oblong, like old yobuild had?
        bs_untar_restricted "$tarball"
    done

    rm -rf bs_install.tmp
}

# If $1 isn't in file $2, append it
bs_append_to_file() {
   if ! fgrep -e "$1" "$2" 2>/dev/null
   then
      printf "# Appended by obs\n%s\n" "$1" >> "$2"
   fi
}

# Set variable bs_gpg with command to invoke gpg2
bs_gpg_init() {
    case "$bs_gpg" in
    "")
        if test -x /usr/bin/gpg2
        then
            bs_gpg=gpg2
        else
            bs_gpg=gpg
        fi

        ;;
    esac

    # horrible kludge to allow loopback on ubuntu 16.04, which still has gpg 2.11
    if $bs_gpg --version | head -n 1 | grep ' 2\.1\.11' > /dev/null
    then
        # Grumble.
        case "$GNUPGHOME" in
        "") GNUPGHOME=$HOME/.gnupghome;;
        esac
        mkdir -p -m700 "$GNUPGHOME"
        local gpgagent_conf="$GNUPGHOME"/gpg-agent.conf
        bs_append_to_file allow-loopback-pinentry "$gpgagent_conf"
    fi
}

# Set up $GNUPGHOME for insecure but fast unattended key generation
bs_gpg_init_insecure_unattended() {
    case "$GNUPGHOME" in
    $HOME|"") bs_abort "bs_gpg_init_insecure_unattended: GNUPGHOME must be set to a short non-HOME path";;
    esac
    local gpgconf="$GNUPGHOME"/gpg.conf
    # Delete mercilessly now because rm -rf $bs_repotop doesn't delete $GNUPGHOME
    gpgconf --kill gpg-agent || true
    rm -rf "$GNUPGHOME"
    mkdir -p -m700 "$GNUPGHOME"
    bs_append_to_file no-tty "$gpgconf"
    bs_append_to_file batch  "$gpgconf"
    bs_gpg_init
}

# Generate a fake key; APT_CONFIG and GNUPGHOME are used to avoid
# contaminating real environment (somewhat)
bs_apt_key_gen() {
    bs_gpg_init
    if $bs_gpg -k | grep -C 1 Kwik-Expiring
    then
       bs_abort "Fake key already exists; do 'obs apt-key-rm' to remove."
    fi
    test "$APT_CONFIG" = "$bs_repotop/etc/apt.conf" || bs_abort "assertion failed"

    # If this is first call, configure private gpg and apt environments
    # (Generally, caller will do rm -rf $bs_repotop at start of the big build.)
    if ! test -f "$APT_CONFIG"
    then
       # Init apt environment
       mkdir -p "$bs_repotop/etc/sources.list.d"
       # Start off trusting everything we trusted before
       cp -a /etc/apt/trusted.gpg* "$bs_repotop/etc"
       # Add Debug::Acquire::gpgv "true"; if needed
       cat > $APT_CONFIG <<_EOF_
Dir::Etc::sourceparts "$bs_repotop/etc/sources.list.d";
Dir::Etc::Trusted "$bs_repotop/etc/trusted.gpg";
Dir::Etc::TrustedParts "$bs_repotop/etc/trusted.gpg.d";
_EOF_
       # Init gpg environment
       bs_gpg_init_insecure_unattended
    fi

    # Generate a repo key that lasts long enough for one build
    local days=30
    local realname="$(getent passwd "$LOGNAME" | cut -d: -f5 | cut -d, -f1)"
    local keyname="Kwik-Expiring Development-Only Key ($realname)"
    local keyemail="temp-repo@example.com"
    cat > gpg.in.tmp <<_EOF_
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: $keyname
Name-Email: $keyemail
Expire-Date: $days
_EOF_

    $bs_gpg -q --pinentry-mode loopback --passphrase '' --personal-digest-preferences SHA256 --gen-key gpg.in.tmp
    rm gpg.in.tmp

    local keyfile
    keyfile=$bs_repotop/repo.pubkey
    $bs_gpg --export $keyemail > "$keyfile"

    #echo "Generated local repo's fake key $keyfile, contents:"
    #$bs_gpg --with-fingerprint "$keyfile"
    #echo "We only need it for one build, so it expires in $days days."
}

bs_apt_key_rm() {
    bs_gpg_init

    local keyfile
    keyfile="$bs_repotop"/repo.pubkey

    if true
    then
        # guess what?  Easiest way to go to nuke it from orbit.
        bs_gpg_init_insecure_unattended
    else
        # The gentle way.  Bit fragile though.
        local keyemail="temp-repo@example.com"
        local fingerprint
        fingerprint=$(gpg -k --with-colons $keyemail | awk -F: '/^fpr:/ {print $10}' | head -n 1)
        $bs_gpg -q --pinentry-mode loopback --passphrase '' --yes --delete-secret-and-public-key "$fingerprint"
    fi

    rm -f "$keyfile"
}

# Make a signed apt server available to the apt command
# Usage:
#   bs_apt_server_add host key dir dir ...
# Use 'none' for no key.
# e.g.
#   bs_apt_server_add localhost dummy.key /var/apt/repo
#   bs_apt_server_add foo.com none /ubuntu
# As called by bs_use_package_repo:
#   bs_apt_server_add buildhost5.oblong.com /tmp/repo.key.3335 repobot/dev-xenial/apt repobot/rel-xenial/apt
# where /tmp/repo.key.nnnn was downloaded from http://buildhost5.oblong.com/oblong.key.
# To sneakly download a different OS's packages, set bs_apt_codename first (e.g. to xenial)
bs_apt_server_add() {
    bs_gpg_init
    local host=$1
    shift
    local key=$1
    shift
    # remaining args are read by for loop below

    local sources_list_d
    local maybesudo
    case $MASTER in
    localhost)
        maybesudo=""
        sources_list_d=${bs_repotop}/etc/sources.list.d
        ;;
    *)
        maybesudo=sudo
        sources_list_d=/etc/apt/sources.list.d
        ;;
    esac

    $maybesudo rm -f "$sources_list_d"/"$host"-*.list
    $maybesudo rm -f "$sources_list_d"/repobot-"$host"-*.list   # transitional
    local _apt_codename
    if test -f /etc/lsb-release
    then
        _apt_codename=${bs_apt_codename:-"$(awk -F= '/CODENAME/{print $2}' /etc/lsb-release)"}
    else
        _apt_codename=${bs_apt_codename:-"$(awk -F= '/VERSION_CODENAME/{print $2}' /etc/os-release)"}
    fi

    # Avoid calling apt-key; instead, use explicit signed-by attribute on sources.list entry
    # Compare with oblong-repo/Makefile's handling of keys
    local signedby
    if test "$key" != "none"
    then
        local keyrings=/usr/share/keyrings

        if grep -q "BEGIN PGP PUBLIC KEY BLOCK" < "$key"
        then
            # can't use an armored key directly... well, we could with apt-1.4 if it were named .asc rather than gpg
            $bs_gpg --dearmor < "$key" > /tmp/obs-key-$LOGNAME.$$.tmp
            key=/tmp/obs-key-$LOGNAME.$$.tmp
        fi
        sudo install -D -m644 "$key" $keyrings/$MASTER.gpg
        rm -f /tmp/obs-key-$LOGNAME.$$.tmp
        # Make the sources.lists.d entry point to that key
        signedby="signed-by=$keyrings/$MASTER.gpg"
    fi

    local dpkgarch=$(dpkg --print-architecture)
    local dir
    local line
    local sdir
    for dir
    do
        sdir="$(echo $dir | tr '/' '-')"
        case "$host" in
        localhost)
            line="deb [arch=$dpkgarch $signedby] file:$dir $_apt_codename main non-free"
            ;;
        *)
            line="deb [arch=$dpkgarch $signedby] http://$host/$dir $_apt_codename main non-free"
            ;;
        esac
        echo "$line" | $maybesudo tee "$sources_list_d/$host-$sdir.list" > /dev/null
    done

    echo "bs_apt_server_add: debug: /etc/apt/sources.list.d entries:"
    grep . /etc/apt/sources.list.d/*.list || true

    sudo GNUPGHOME="$GNUPGHOME" APT_CONFIG="$APT_CONFIG" apt-get -q -q update
}

# Undo bs_apt_server_add
# Usage:
# bs_apt_server_rm host
bs_apt_server_rm() {
    local host=$1
    shift
    local sources_list_d
    case $MASTER in
    localhost)
        sources_list_d=${bs_repotop}/etc/sources.list.d
        rm -f "$sources_list_d"/repobot-"$host"-*.list  # remove soon
        rm -f "$sources_list_d"/"$host"-*.list
        ;;
    *)
        sources_list_d=/etc/apt/sources.list.d
        sudo rm -f "$sources_list_d"/repobot-"$host"-*.list  # remove soon
        sudo rm -f "$sources_list_d"/"$host"-*.list
        ;;
    esac
    sudo GNUPGHOME="$GNUPGHOME" APT_CONFIG="$APT_CONFIG" apt-get -q clean
    sudo GNUPGHOME="$GNUPGHOME" APT_CONFIG="$APT_CONFIG" apt-get -q update
}

# Create a package $1 with version $2 claiming to be in section $3
bs_apt_pkg_gen() {
    local name=$1
    local version=$2
    local section=$3

    rm -rf dummy.$$
    mkdir -p dummy.$$/debian/usr/local/bin
    cat > dummy.$$/debian/usr/local/bin/hello <<_EOF_
#!/bin/sh
echo 'hello, world!'
_EOF_
    chmod +x dummy.$$/debian/usr/local/bin/hello
    mkdir dummy.$$/debian/DEBIAN
    cat > dummy.$$/debian/DEBIAN/control <<_EOF_
Package: $name
Version: $version
Section: $section
Priority: optional
Architecture: all
Depends: base-files
Maintainer: Alfred E. Neuman <what@worry.me>
Description: Tiny package
 This package gives reprepro something to chew on.
_EOF_
    (cd dummy.$$
    dpkg-deb --build debian > /dev/null
    )
    mv dummy.$$/debian.deb ${name}_${version}_all.deb
    rm -rf dummy.$$
}

# Usage: bs_apt_server_init subdir pubkey [distro1 ...]
# Create an apt server rooted at $bs_repotop/subdir/apt  (FIXME: flip last two dirs someday)
# Pubkey can be either a short id or a pubkey file.
# Remaining arguments are which distros this repo should serve.
bs_apt_server_init() {
    local apt_subdir="$1"
    shift
    local apt_repokey="$1"
    shift
    local apt_suites="$*"
    bs_gpg_init

    if test "$apt_suites" = ""
    then
        apt_suites="$(awk -F= '/CODENAME/{print $2}' /etc/lsb-release)"
    fi

    if test -f "$apt_repokey"
    then
        # Extract first public key fingerprint from a public key file
        apt_repokey=$($bs_gpg --with-colons "$apt_repokey" | awk -F: '/^pub:/ {print $5}' | head -n 1)
    fi

    local apt_archive_root="$bs_repotop/$apt_subdir/apt"
    if test -d "$apt_archive_root"
    then
        bs_abort "$apt_archive_root already exists"
    fi

    local apt_arches="i386 amd64 armhf source"
    local apt_sections="main non-free"

    local suite
    for suite in $apt_suites
    do
        mkdir -p "$apt_archive_root"/dists/"$suite"   # just so we can do sanity checks before uploading
    done
    local section
    for section in $apt_sections
    do
        mkdir -p "$apt_archive_root"/pool/"$section"
    done
    mkdir -p "$apt_archive_root"/conf
    > "$apt_archive_root"/conf/distributions
    for suite in $apt_suites
    do
        cat >> "$apt_archive_root"/conf/distributions <<_EOF_
Origin: obs
Label: obs
Codename: $suite
Architectures: $apt_arches
Components: $apt_sections
Description: hello my name is apt repository
SignWith: $apt_repokey

_EOF_
    done

    # We don't usually like installing these on the fly, but it makes bootstrapping easier
    if ! reprepro --version > /dev/null 2>&1
    then
        sudo apt-get install -q -y reprepro
    fi
    # Now upload a dummy package to every section of every suite so "apt-get update" doesn't error out
    for section in $apt_sections
    do
        bs_apt_pkg_gen obs-hello-${section} 0.0.1 $section
        for suite in $apt_suites
        do
            if ! reprepro --silent --ask-passphrase -S $section -Vb "$apt_archive_root" includedeb "$suite" obs-hello-"${section}"_0.0.1_*.deb > /tmp/reprepro.log.$$ 2>&1
            then
               cat /tmp/reprepro.log.$$
               bs_abort "reprepro includedeb failed"
            fi
            rm /tmp/reprepro.log.$$
        done
        rm obs-hello-${section}_0.0.1_*.deb
    done
}

# Usage: bs_apt_pkg_add subdir suite pkg...
# Add given packages to distro $suite in the apt server rooted at $bs_repotop/subdir/apt
bs_apt_pkg_add() {
    local apt_subdir="$1"
    shift
    local apt_suite="$1"
    shift
    local apt_pkgs="$*"

    local apt_archive_root="$bs_repotop/$apt_subdir/apt"

    if ! test -d "$apt_archive_root"/dists
    then
        bs_abort "1st arg $apt_subdir looks wrong; no such directory $apt_archive_root/dists."
    fi
    if test -f "$apt_suite"
    then
        bs_abort "2nd arg should not be a .deb, it should be a suite name, like precise or quantal."
    fi
    if ! test -d "$apt_archive_root"/dists/"$apt_suite"
    then
        bs_abort "2nd arg (codename aka suite) $apt_suite does not exist in this apt repository."
    fi

    case "$apt_pkgs" in
    "") bs_abort "No packages were given to upload.";;
    esac

    for arg in $apt_pkgs
    do
        test -f "$arg" || bs_abort "Package $arg is not a file."
    done

    # Acquire an exclusive lock on this repo
    # See how fd 9 is set up by redirection at end of this function
    local LOCKFILE=$apt_archive_root/reprepro.lock

    #echo "Acquiring lock $LOCKFILE... time is `date`"
    (
    if ! flock 9
    then
        bs_abort "Could not aquire lock $LOCKFILE"
    fi
    #echo "Acquired lock $LOCKFILE... time is `date`"

    # Whew.  All that sanity checking, and the payload is just one line.

    # Site-specific behavior ...
    case "$apt_subdir" in
    dev-*)
        # Remove the previous version of these packages to avoid dreaded
        # "Already existing files can only be included again, if they are the same, but..."
        # at least for dev builds, so people can force builds after an iz change.
        # Handle a mixture of native and portable packages (they require different args to reprepro)
        for arg in $apt_pkgs
        do
            local pkgarch=$(echo $arg | awk '{print $1}' | sed 's/.*_//;s/\.deb//')
            # remove first _ and everything after it, and first / and everything before it, yielding the package name
            local pkgname=${arg%%_*}
            pkgname=${pkgname##*/}

            case "$pkgarch" in
            all) reprepro -Vb $apt_archive_root remove $apt_suite $pkgname;;
            *)   reprepro --architecture $pkgarch -Vb $apt_archive_root remove $apt_suite $pkgname;;
            esac
        done
        ;;
    esac

    # Note: Remove the --ask-passphrase once you've configured a key without one, or configured an agent, or something
    set +e
    LANG=C reprepro --ask-passphrase -P extra -Vb $apt_archive_root includedeb $apt_suite $@ > /tmp/reprepro.log.$$ 2>&1
    status=$?
    set -e
    if grep "Already existing files can only" /tmp/reprepro.log.$$ > /dev/null
    then
        cat /tmp/reprepro.log.$$
        rm /tmp/reprepro.log.$$
        bs_abort "Repeat upload failed.  Possible cause: You can only upload a rel package once.  Maybe you meant to give this package a dev- tag?"
    fi
    echo $status > subshell.status.tmp
    if test $status -ne 0
    then
        cat /tmp/reprepro.log.$$
        rm /tmp/reprepro.log.$$
        bs_abort "Upload failed, see message above."
    fi
    rm /tmp/reprepro.log.$$

    ) 9>"$LOCKFILE"
    #echo "Released lock $LOCKFILE... time is `date`"
    local status
    status=$(cat subshell.status.tmp)
    rm -rf subshell.status.tmp
    if test "$status" != "0"
    then
        bs_abort "Upload failed, see message above."
    fi
}

# Usage: bs_apt_pkg_rm subdir suite pkg...
bs_apt_pkg_rm() {
    local apt_subdir="$1"
    shift
    local apt_suite="$1"
    shift
    local apt_pkgnames="$*"

    local apt_archive_root="$bs_repotop/$apt_subdir/apt"
    if ! test -d $apt_archive_root/dists
    then
        bs_abort "1st arg $apt_subdir looks wrong; no such directory $apt_archive_root/dists."
    fi
    if ! test -d $apt_archive_root/dists/$apt_suite
    then
        bs_abort "2nd arg (codename aka suite) $apt_suite does not exist in this apt repository."
    fi

    local LOCKFILE="$apt_archive_root"/reprepro.lock

    #echo "Acquiring lock $LOCKFILE... time is `date`"
    (
    reprepro -Vb $apt_archive_root remove $apt_suite $@
    ) 9>"$LOCKFILE"
    #echo "Released lock $LOCKFILE... time is `date`"
}

# Download a set of packages and their dependencies into the current directory,
# filtering out any not from $MASTER.  This is a bit dirty.
# On entry:
#    you must already have access to the right repos on $MASTER
#    you must already have executed 'sudo apt clean'
bs_apt_pkg_get_transitive() {
    local filter
    case $MASTER in
    localhost) filter=file;;
    *)         filter=$MASTER;;
    esac

    # It is risky to parse verbose tool output, but I dunno where else to get the info.
    # Ubuntu 14.04: Get:1 http://buildhost5.oblong.com/repobot/rel-trusty/apt/ trusty/non-free oblong-loam3.30 amd64 3.30.12-0 [74.0 kB]
    # Ubuntu 16.04: Get:2 http://buildhost5.oblong.com/repobot/rel-xenial/apt/ xenial/non-free amd64 oblong-loam3.30 3.30.12-0 [74.0 kB]
    local field
    case $_os in
    ubu1404)
       field=4;;
    *) field=5;;
    esac

    local expanded
    for pkg in $(sudo GNUPGHOME="$GNUPGHOME" APT_CONFIG="$APT_CONFIG" apt-get install --download-only -y $* | awk '/^Get:[0-9].*:/ { print $'$field'}')
    do
        if apt-cache policy $pkg | grep -w -q ${filter}
        then
            expanded="$expanded $pkg"
        fi
    done

    apt-get -q download $expanded
}

# Delete current build subdir, kill lingering build jobs, show disk space.
bs_purge_build() {
    case $_os in
    ubu*|osx*)
        echo "Disk space before purge:"
        df -h .
        if test -d build
        then
            if ! rm -rf build || test -d build
            then
                $SUDO rm -rf build
            fi
        fi
        echo "Disk space after purge:"
        df -h .
        ;;
    cygwin*)
        # Kill off lingering build processes.  See e.g.
        # http://blog.peter-b.co.uk/2017/02/stop-mspdbsrv-from-breaking-ci-build.html
        # https://chromium.googlesource.com/chromium/tools/build/+/master/scripts/slave/kill_processes.py
        tasklist
        for exe in git.exe ninja.exe mspdbsrv.exe node.exe pool_tcp_server.exe
        do
            taskkill /F /T /IM $exe || true
        done

        # Delete using cmd, it's faster
        # Move off to the side in case it takes too long and buildbot moves on
        echo "Disk space before purge:"
        cmd /c dir
        cmd /c rmdir /s /q build.deleteme.* || true
        dest=build.deleteme.$$
        cmd /c "ren build $dest & rmdir /s /q $dest"
        echo "Disk space after purge:"
        cmd /c dir
        ;;
    *) bs_abort "unsupported os $_os";;
    esac
}

#----------- begin upload support ---------------------------------------------------
# Not pretty.  Needs cleaning up.

# True if environment says this is a try build
bs_is_try_build() {
    case "$PWD" in
	*-trybuilder*|*-try-*) return 0;;  # true
	*) return 1;;  # false
    esac
}

# True if environment says not to publish the artifacts
bs_no_publish()
{
    if test "$BUILDSHIM_LOCAL_ALREADY_RUNNING" != ""
    then
        echo "Allowing upload even in a trybuilder, since it seems to be a nice safe uberbau build"
    else
        if bs_is_try_build
        then
            bs_warn "this is a try build, so not fully publishing artifacts"
            return 0
        fi
    fi
    if test "$BS_NO_PUBLISH"
    then
        bs_warn "BS_NO_PUBLISH set, so not fully publishing artifacts"
        return 0
    fi
    if test "$BS_NO_APT_UPLOAD"
    then
        bs_warn "BS_NO_APT_UPLOAD set, so not fully publishing artifacts.  (Deprecated; please set BS_NO_PUBLISH instead.)"
        return 0
    fi
    false
}

bs_create_empty_dir_on_master() {
    local dir=$1
    if echo "$dir" | egrep '^$|^/$|^/home/[a-z0-9]*$|^~[a-z0-9]*$|/$'
    then
        bs_abort "bs_create_empty_dir_on_master: directory $dir too dangerous to nuke" >&2
    fi
    if ! test "$BS_NO_CLEAN_UPLOAD"
    then
        local max_safe_size=3000000  # 3GB (qt 5.9 is 2.5GB on windows)
        case "$MASTER" in
        localhost)
            if test -d "$dir" && test "$(du -s "$dir" | cut -f1)" -gt $max_safe_size
            then
                bs_abort "directory $dir too big, aborting"
            else
                rm -rf "$dir"
            fi
            ;;
        *) ssh -o StrictHostKeyChecking=no -n "$(bs_get_install_sshspec)" "if test -d '$dir' && test \$(du -s '$dir' | cut -f1) -gt $max_safe_size; then echo 'directory $dir too big, aborting'; exit 1; else rm -rf '$dir'; fi";;
        esac
    fi
    case "$MASTER" in
    localhost) mkdir -p "$dir";;
    *) ssh -o StrictHostKeyChecking=no -n "$(bs_get_install_sshspec)" "mkdir -p '$dir'";;
    esac
}

# Output the name of the artifact directory
# Should be of the form $(bs_get_builder_name)/$buildnum
# If bs_artifactsubdir has been set (say, by bs_pkg_init), returns that.
# If on buildbot, reads magic file ob-repobot left in the parent directory.
# If on gitlab-ci, reads magic environment variable.
# Else returns the string "default" (an old convention).
bs_get_artifact_subdir() {
    if test "${bs_artifactsubdir}" != ""
    then
        echo "${bs_artifactsubdir}"
    elif test -f ../bs-artifactsubdir
    then
        # See ob-repobot/common/SimpleConfig.py
        cat ../bs-artifactsubdir
    elif test -f "${bs_origdirslash}../bs-artifactsubdir"
    then
        # obs_funcs.sh sets bs_origdir when sourced
        # This matters on windows buildbots, which change to a short directory before building deeply nested things
        cat "${bs_origdirslash}../bs-artifactsubdir"
    elif test "$CI_PROJECT_PATH_SLUG" != ""
    then
        # See https://docs.gitlab.com/ee/ci/variables/
        # Requires gitlab >= 9.3
        # We could just use "$slog/$job", but let's leave a few more breadcrumbs than that.
        echo "$CI_PROJECT_PATH_SLUG-$_os-$CI_PIPELINE_ID/$CI_JOB_ID"
    else
        echo "default"
    fi
}

# Our buildbot's master.cfg calls this to tell us where it wants artifacts uploaded to.
#
# This used to be just a shell command in master.cfg, but that
# doesn't work with native win32 build workers.
# So now master.cfg runs obs (which on native windows buildbots is obs.bat,
# which invokes this script via cygwin or git-bash as appropriate).
bs_set_artifact_subdir() {
    # FIXME: do we need to handle other cases?
    printf '%s\n' "$1" > ../bs-artifactsubdir
}

# If running on a buildbot, output its name and return true
# If not running on a buildbot, return false.  FIXME: return git repo name for local source build use case?
bs_get_builder_name() {
    case "$BS_FORCE_BUILDER_NAME" in
    "") ;;
    *) echo "$BS_FORCE_BUILDER_NAME"; return 0;;
    esac

    dir="$(pwd)"
    case "$dir" in
    *slave-state*) ;;
    *) return 1;;   # false
    esac

    # Strip '/build' suffix and remove dirname
    echo "$dir" | sed 's,/build/.*,,;s,/build$,,;s,.*/,,'
    return 0
}

# Retrieve source package name from debian directory
bs_get_package_name() {
    awk '/Source:/ {print $2};' < "${bs_origdirslash}debian/control"
}

# Deps mechanism

bs_deps_file() {
    # piss-poor place to put it, but it works everywhere
    echo ../install_deps.log
}

bs_deps_clear() {
   rm -f $(bs_deps_file)
}

# Called by bs_install (on mac and win) and bs_deps_append_log (on ubuntu)
# Stdin is a list of packages that were installed,
bs_deps_append() {
   # Remove paths
   # Throw away anything after an underscore (version on Ubuntu)
   # Throw away suffixes like -4.0.6-0.tar.gz (version on Mac)
   tr ' ' '\012' | sed 's,.*/,,;s/_.*//;s/-[-0-9.]*.tar.gz//' >> $(bs_deps_file)
}

# Stdin is a list of:
#   bare package names and/or
#   package tarball names and/or
#   the output of dpkg -i, apt-get install, and/or apt-get install -s.
# Stdout is a list of bare package names, with no version suffixes,
# with duplicates and junk packages filtered out.
# FIXME: the output of apt-get install is not language-independent,
# so for best results use the C locale when running apt-get.
# (The output of apt-get install -s does not have this problem.)
bs_deps_filter_log() {
   grep -v "Unpacking replacement" |
     grep -v build-deps |
     awk '/^Unpacking |^Inst / {print $2} NF==1 && /^[a-z][-.a-z0-9]*$/ {print} /tar.gz/ {print}' |
     LANG=C sort -u
}

# Ubuntu only.
# Like bs_deps_append, but stdin is the output of dpkg and/or apt-get install
# and/or apt-get install -s.
bs_deps_append_log()
{
   bs_deps_filter_log | bs_deps_append
}

# List the packages installed since bs_deps_clear
bs_deps_list() {
    bs_deps_filter_log < $(bs_deps_file) || true
}

# Ubuntu only.
# Uninstall all dependencies we know about, including any build-deps,
# and anything they pulled in, then clear dependency list.
bs_apt_uninstall_deps() {
    # Regular expression for packages to not remove, even though they are may be from oblong
    # The mesa/libgbm1/libxatracker2 entries are to avoid removing build products of oblong-mesa
    # Keep this list in sync with the one in ob-remove.sh.
    local whitelist_re="bzip2|oblong-obs|-mesa|mesa-|libgbm1|libxatracker2|[^g]udev|systemd|ubuntu-keyring"

    $SUDO apt-get -q autoremove --purge -y $(bs_deps_list | egrep -v "$whitelist_re") 'build-deps*' || true
    bs_deps_clear
}

# At build time, each builder will create two text files:
#  $platform / $buildername.in, containing the input files it downloads
#  $platform / $buildername.out, containing the output files it uploads
# These will later be used by common/SimpleConfig.py to set up dependencies

# Call when uploading; arguments are the packages we're uploading
bs_deps_hook() {
    if ! buildername=$(bs_get_builder_name)
    then
        echo "bs_deps_hook: not running on buildbot, so not saving dependency info"
        bs_deps_clear
        return 0
    fi
    echo "bs_deps_hook: builder $buildername reporting it uploads following artifacts: '$*'"
    rm -rf bs_deps.tmp
    mkdir bs_deps.tmp

    # Treat arguments as package files, save in $buildername.out, one per line
    # Remove paths
    # Throw away anything after an underscore (version on Ubuntu)
    # Throw away suffixes like -4.0.6-0.tar.gz (version on Mac)
    echo $* | tr ' ' '\012' | sed 's,.*/,,;s/_.*//;s/-[-0-9.]*.tar.gz//' \
     > bs_deps.tmp/$buildername.out

    # Save accumulated dependencies (but ignore self at all costs)
    bs_deps_list | fgrep -v  --line-regexp -f bs_deps.tmp/$buildername.out > bs_deps.tmp/$buildername.in || true

    if ! echo bs_deps.tmp/* | fgrep '/*' > /dev/null
    then
        ls -l bs_deps.tmp

        deps_dest=$bs_repotop/bs_deps/$_os
        case ${MASTER} in
        localhost)
            mkdir -p $deps_dest
            cp bs_deps.tmp/* $deps_dest
            ;;
        *)
            ssh -o StrictHostKeyChecking=no -n "$(bs_get_install_sshspec)" mkdir -p "$deps_dest"
            scp -o StrictHostKeyChecking=no bs_deps.tmp/* "$(bs_get_install_sshspec):$deps_dest/"
            ;;
        esac
    fi
    rm -rf bs_deps.tmp
    bs_deps_clear
}

bs_version_is_dev()
{
    # Odd Y means dev version
    if echo "$1" | egrep -q '^[0-9]+\.[0-9]*[13579]$|^[0-9]+\.[0-9]*[13579]\.[0-9]*$'
    then
        echo version $1 was dev >&2
        return 0
    else
        echo version $1 was rel >&2
        return 1
    fi
}

bs_get_project_buildtype_override() {
    # FIXME: project's buildshim should just set BS_FORCE_BUILDTYPE ?
    if bs_get_package_name | egrep -q 'oblong-admin-web|oblong-appup|mezz|mz'
    then
        bs_warn "Always using dev for mezz, even on rel branches." >&2
        echo dev
        return 0
    fi
    false
}

# Return which kind of repositories this build needs access to (dev or rel).
# Rule is:
#   If it's on a branch named rel*, and it depends on a rel version of g-speak, it should only have access to rel repos.
#   Otherwise it needs access to dev (and rel).
bs_intuit_buildtype_deps() {
    if test "$BS_FORCE_BUILDTYPE"
    then
        echo $BS_FORCE_BUILDTYPE
        return
    fi

    # Output project override, if any
    if bs_get_project_buildtype_override
    then
        return
    fi

    # If it is itself on a dev branch, it needs access to dev repos.
    case $(git describe) in
    rel*) ;;
    *)    echo "dev"; return;;
    esac

    # If it depends on a dev version of g-speak, it needs access to dev repos.
    if test "$gspeak" = ""
    then
        gspeak=$(bs_get_gspeak_version)
        if test "$?" != 0 || test "$gspeak" = ""
        then
            # Does not depend on g-speak at all
            echo "rel"; return
        fi
    fi
    if bs_version_is_dev "$gspeak"
    then
        echo "dev"; return
    fi

    echo "rel"
}

# Return which kind of repository to upload the result of this build to (dev or rel).
# If you're uploading a file, pass the name of the file being uploaded.
# Rule is:
#   If it was built with rel dependencies, is on a branch named rel*, and is tagged, it should be uploaded to a rel repo.
#   Otherwise it should be uploaded to a dev repo.
bs_intuit_buildtype() {
    if test "$BS_FORCE_BUILDTYPE"
    then
        echo $BS_FORCE_BUILDTYPE
        return
    fi

    case "$version_patchnum" in
    ""|0) ;;
    *)
        bs_warn "Not tagged, so marking this as a dev build." >&2
        echo "dev"; return;;
    esac

    # Otherwise upload to same kind of repo we get dependencies from.
    local ret=$(bs_intuit_buildtype_deps)

    # Sanity check -- if we're uploading files that refer to a dev
    # g-speak, make sure bs_intuit_buildtype_deps gave us access to dev repo.
    # FIXME: remove this, along with the argument?
    case $1 in
    *gs[0-9]*\.[0-9][13579]x*|*gs-gh[0-9]*\.[0-9][13579]x*)
        if test $ret != dev
        then
            bs_abort "BUG: bs_intuit_buildtype_deps should have already noticed you're using dev g-speak"
        fi
    esac

    echo $ret
}

# FIXME: old, awkward
# FIXME: this is the pair to bs_install
# FIXME: this should be part of bs_upload, or vice versa
bs_upload2()
{
    local project os abi micro changenumber

    project=$1;      shift
    os=$1;           shift
    abi=$1;          shift
    micro=$1;        shift
    changenumber=$1; shift

    case $os in
    osx*|cygwin|mingw|ubu*) ;;
    *) bs_abort "unrecognized os $os";;
    esac
    test $project || bs_abort "expected project"
    test $abi || bs_abort "expected abi"
    test $micro || bs_abort "expected micro"
    test -f $micro && bs_abort "micro should not be a file"
    test $changenumber || bs_abort "expected changenumber"
    test -f $changenumber && bs_abort "changenumber should not be a file"

    # Publish artifacts to the bs_install repo if appropriate
    if ! bs_no_publish
    then
        builds_dest=$bs_install_root/$project/$os/$abi/$micro/$changenumber
        bs_create_empty_dir_on_master $builds_dest
        case $MASTER in
        localhost)
          cp -a $* $builds_dest
          ;;
        *)
          scp -o StrictHostKeyChecking=no -p "$@" "$(bs_get_install_sshspec):$builds_dest/"
          ;;
        esac
        # Only fire the dependency hook if we actually publish (else try builders will sneak into the list of things to trigger)
        bs_deps_hook $*
    fi

    # Aaaand upload it again to the place buildbot's 'artifacts' link goes
    # bs_upload() has similar logic
    local artifactdir
    artifactdir="$(bs_get_artifact_subdir)"
    case "$artifactdir" in
    ""|"default")
        bs_warn "No build number from buildbot, so not archiving build artifacts"
        ;;
    *)
        kind=$(bs_intuit_buildtype $*)
        shasum $* | sed 's, .*/, ,' | tee sha1sums.txt
        builds_dest=$bs_repotop/$kind/builds/$artifactdir

        bs_create_empty_dir_on_master $builds_dest
        case $MASTER in
        localhost)
          cp -a $* sha1sums.txt $builds_dest
          ;;
        *)
          scp -o StrictHostKeyChecking=no -p "$@" sha1sums.txt "$(bs_get_install_sshspec):$builds_dest/"
          ;;
        esac
        ;;
    esac

    # Clear list of dependencies even if bs_no_publish, else next call to bs_deps_hook might get extra dependencies
    bs_deps_clear
}

#----------- end upload support ---------------------------------------------------

bs_set_globals() {
    _os=$(bs_detect_os)

    SUDO=sudo
    case $_os in
    cygwin|mingw) SUDO="" ;;
    esac

    DRIVEC=/wrong/os
    case $_os in
    cygwin) DRIVEC=/cygdrive/c/; MSYS_ESC=;;
    mingw) DRIVEC=/c; MSYS_ESC=/;;
    esac

    # FIXME: provide fewer variables
    # Most of these are from lazy old code

    bs_repodir=${bs_repodir:-repobot}

    # To do local builds, set MASTER to localhost, and bs_repotop to where to store
    # artifacts, then do e.g. obs apt-key-gen; brepo.sh init
    case "$MASTER" in
    "") ;;
    localhost)
	bs_upload_user=$LOGNAME
	# Change behavior of apt.  Careful, have to pass it through sudo!
	export APT_CONFIG="$bs_repotop/etc/apt.conf"
	# Change behavior of gpg.  Careful, have to pass it through sudo!
	# Alas, GNUPGHOME has to be a short absolute path,
	# as on Ubuntu 16.04, we don't have gpgconf --create-socketdir.
	# FIXME: this is likely to clash if run in parallel.
	if test "$BS_GNUPGHOME"
	then
	    # Workaround to avoid clash during 'localbuild.sh build nobuild'
	    echo "obs_funcs: Setting GNUPGHOME from BS_GNUPGHOME, only used by debian/rules as of this writing" >&2
	    GNUPGHOME="$BS_GNUPGHOME"
	else
	    GNUPGHOME=/tmp/obs_localbuild_gpghome_$LOGNAME.tmp
	fi
	export GNUPGHOME
	;;
    esac
    bs_repotop=${bs_repotop:-/home/buildbot/var/$bs_repodir}
    MASTER=${MASTER:-$(bs_default_master)}
    export MASTER   # needed by debuild ...
    bs_upload_user=${bs_upload_user:-buildbot}
    bs_install_root=$bs_repotop/tarballs
    bs_origdir="$(pwd)"
    bs_origdirslash="$bs_origdir/"

    # Allow user to download as a different user
    bs_get_install_sshspec() {
	if test "$bs_install_user"
	then
	    echo ${bs_install_user}@${MASTER}
	elif test "$LOGNAME" = SYSTEM
	then
	    # Odd case: if running as service on cygwin, don't use name of system user.
	    echo ${bs_upload_user}@${MASTER}
	else
	    # Default: just use your own user id when sshing to MASTER
	    echo ${MASTER}
	fi
    }
    # Globals that contain the value of MASTER and are only set on startup
    # don't work well when you try stuff like
    #    BS_KEEP_IT=true MASTER=buildhost4.oblong.com bs_upload_debs
    #    BS_KEEP_IT=true MASTER=buildhost5.oblong.com bs_upload_debs
    # as bau-defaults/buildshim-ubu currently does.
    # Replace all uses of bs_install_sshspec with $(bs_get_install_sshspec)
    bs_install_sshspec=obsolete-use-bs_get_install_sshspec-instead
}

# It was a design mistake to set globals by default.  Make it optional so callers
# can use e.g. bs_detect_os and bs_default_master without setting all the globals,
# and then call bs_set_globals at their leisure.
case $BS_SET_GLOBALS in
""|"true")
    # Provide a few variables by default
    bs_set_globals;;
"false") ;;
*) bs_abort "obs_funcs.sh: BS_SET_GLOBALS set to $BS_SET_GLOBALS ?";;
esac
