#------ functions for use from buildshims -------
# Caution: set -e doesn't work in functions that are evaluated as the
# argument of an if statement.  Error checking should be explicit.
# See http://unix.stackexchange.com/questions/65532/why-does-set-e-not-work-inside

# Note: this file contains a number of older or less useful functions
# The useful and well-done ones have been hoisted out into obs_funcs.sh.
# Please keep obs_funcs.sh tidy and well-reviewed,
# clean up useful stuff and move it into obs_funcs.sh once it's tidy,
# and delete stuff in bs_funcs.sh once it no longer has uses.
# Scripts that currently source bs_funcs.sh should switch
# to sourcing obs_funcs.sh if possible.

. obs_funcs.sh

# OB_DUMPER_HOST is where to upload very final public things that humans or ob-machine-setup.pl depend on
# It should be the hostname of machine with the global NFS-mounted /ob/dumper tree
# (or, when doing isolated builds, a machine with a local /ob/dumper directory)
export OB_DUMPER_HOST=${OB_DUMPER_HOST:-git.oblong.com}

# We want to be able to build each of our packages
# for all supported distros and versions.
# But we want .deb's and .rpm's to have unique names
# to reduce user confusion.  Also, Debian pools mix together
# packages for all distro versions.
# Therefore package filenames have to include the distro
# name/version to avoid clashing.
# Happily, there are existing conventions for how to do this.
#
# In Debian, +codenameNN is appended to the debian_revision field
# for security releases.  We're not doing security releases, but hey.
# See http://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version
# and http://stackoverflow.com/questions/1831188/
#
# In RPM-land, it's common to tag packages with a distribution
# name by appending a %{dist} code in the Release field.
# See http://fedoraproject.org/wiki/Packaging:DistTag

bs_os_codename() {
    case $1 in
    ubu1204) echo precise;;
    ubu1404) echo trusty;;
    ubu1604*) echo xenial;;
    ubu1804) echo bionic;;
    ubu1904) echo disco;;
    osx*)    echo $1;;       # happens if doing bs_stamp_debian_changelog on osx
    *) bs_abort "bs_os_codename: don't know codename for $1 yet";;
    esac
}

bs_os_pkg_suffix() {
    case $1 in
    ubu1204) echo "+precise";;
    ubu1404) echo "+trusty";;
    ubu1604*) echo "+xenial";;
    ubu1704) echo "+zesty";;
    ubu1710) echo "+artful";;
    ubu1804) echo "+bionic";;
    fc5) echo ".fc5";;
    *) bs_abort "os_pkg_suffix: unknown os '$_os'";;
    esac
}

# Echo the package name suffix as given by git
# Used by admin-web-* repos
bs_get_custom_name_git() {
    # git describe --long's output looks like
    # name-COUNT-CHECKSUM
    # or, if at a tag,
    # name
    d1=$(git describe --long)
    # Strip off -CHECKSUM suffix, if any
    d2=$(echo $d1 | sed 's/-g[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]*$//')
    # Strip off -COUNT suffix, if any
    d3=$(echo $d2 | sed 's/-[0-9]*$//')
    # Remove non-numeric prefix (e.g. rel- or debian/), if any
    d4=$(echo $d3 | sed 's/^[^0-9]*//')
    # Remove numeric prefix, leaving just non-numeric suffix (e.g. -infocomm), if any
    d5=$(echo $d4 | sed -e 's/[0-9][0-9\.]*-/-/g')
    case $d5 in
        -mz-*) echo ;; # Standard/official builds do not get suffix
        -mzq-*) echo $d5 | sed -e 's,-mzq,,g' ;; # Custom builds (tagged mzq) get a suffix
        *) echo ;; # tags not matching expected format get no suffix
    esac
}

# Echo the shource hash as given by git
bs_get_hash_git() {
    git rev-parse --short HEAD
}

bs_stamp_debian_changelog() {
    distro_codename=$(bs_os_codename $_os)

    case "$version" in
    [0-9]*) ;;
    *) bs_abort "bs_stamp_changelog: bad version '$version'";;
    esac
    case "$version_patchnum" in
    [0-9]*) ;;
    *) bs_abort "bs_stamp_changelog: bad version_patchnum '$version_patchnum'";;
    esac

    # If patchnum is empty or zero, don't append it as suffix
    case "$version_patchnum" in
    ""|0) suffix="";;
    *)
      if test "$BS_NO_HASH" = true
      then
          hash=""
      else
          hash="+g$(bs_get_hash_git)"
      fi
      suffix="-$version_patchnum$hash"
      ;;
    esac

    sed -i.bak "1s/(.*/($version$suffix) $distro_codename; urgency=low/" debian/changelog
    rm -f debian/changelog.bak
}

# Apply workarounds commonly needed on non-linux platforms
bs_platform_workarounds() {
    SUDO=sudo
    case $APT_CONFIG in
    "") ;;
    *) SUDO="sudo GNUPGHOME=$GNUPGHOME APT_CONFIG=$APT_CONFIG"
        ;;
    esac

    DRIVEC=/wrong/os
    case $_os in
    cygwin) DRIVEC=/cygdrive/c/;;
    mingw) DRIVEC=/c;;
    esac

    case $_os in
    cygwin)
        # Get access to batch files next to the main script
        WSRC=$(cygpath -w $SRC)
        # Work around http://www.cmake.org/Bug/print_bug_page.php?bug_id=13131
        unset TMP TEMP tmp temp
        export TMP=c:\\windows\\temp
        export TEMP=c:\\windows\\temp

        #PATH=/bin:$PATH  # find Cygwin's find.exe rather than Windows'
        SUDO=
        ;;
    osx*)
        # bare make needs -l$ncores, especially on mac, but debuild can't handle it
        parallel="-j$ncores -l$ncores"
        ;;
    esac

    # Check resources
    # Work around https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/867806
    # by not aborting if df complains about not being able to open a .gvfs.
    free="$(df / | sed 's/Program Files/Program.Files/' | egrep '/$|^\//' | awk '{print $2}')"
    case "$free" in
    "") # on ubuntu core, df / shows space on /home
        free="$(df . | sed 's/Program Files/Program.Files/' | tail -n 1 | awk '{print $2}')";;
    esac

    #echo "Disk space on /: $free blocks"
    if test "$free" -lt 2000000
    then
        bs_abort "Insufficient free space ($free), wanted 2,000,000 blocks"
    fi
    # Show RAM, too, at least on Linux; handy on raspberry pi.
    #free 2> /dev/null || true
}

MIN_MACOSX_VERSION=10.7    # but see below
opt_toolchain=default

# Usage:
#   opt_toolchain=[default|clangcxx11]
#   bs_set_cflags [32|64|universal]
# Sets CFLAGS, CXXFLAGS, OBJCFLAGS, and LDFLAGS as well as CC, CXX, OBJC, CPP, and CXXCPP
# Only supported on Mac for now
bs_set_cflags() {
    unset OBJCFLAGS || true
    unset CXXCPP || true

    # On 10.7 and 10.9, we target 10.7
    # On 10.9 and above, we target 10.9 (and thus libc++)
    # On 10.11, we target 10.11 (we seem to like odd versions)
    case $_os in
        osx107) ;;
        osx109|osx1010) MIN_MACOSX_VERSION=10.9;;
        osx1011) MIN_MACOSX_VERSION=10.11;;
        osx1012) MIN_MACOSX_VERSION=10.12;;
        osx1013) MIN_MACOSX_VERSION=10.13;;
        osx1014) MIN_MACOSX_VERSION=10.14;;
        osx1015) MIN_MACOSX_VERSION=10.15;;
        *) bs_abort "Unrecognized version of macosx";;
    esac

    export CFLAGS="-mmacosx-version-min=$MIN_MACOSX_VERSION"
    export CXXFLAGS="-mmacosx-version-min=$MIN_MACOSX_VERSION"
    export LDFLAGS="-mmacosx-version-min=$MIN_MACOSX_VERSION"

    case $opt_toolchain in
    default)
        # With XCode 5, this is really clang, but that's ok.
        export CC="gcc"
        export CXX="g++"
        export OBJC="gcc"
        ;;
    clangcxx11)
        # Most apps are ok with CXX having flags in it, but Qt is not.
        export CC=clang
        CXXFLAGS="$CXXFLAGS -std=c++11 -stdlib=libc++"
        LDFLAGS="$LDFLAGS -stdlib=libc++ -lc++"
        export CXX=clang++
        export OBJC=clang
        ;;
    esac

    case "$1" in
    32) export CFLAGS="$CFLAGS -m32"
        export CXXFLAGS="$CXXFLAGS -m32"
        export OBJCFLAGS="-m32"
        export LDFLAGS="$LDFLAGS -m32"
        ;;
    64)
        ;;
    universal)
        export CFLAGS="$CFLAGS -arch i386 -arch x86_64"
        export CXXFLAGS="$CXXFLAGS -arch i386 -arch x86_64"
        export OBJCFLAGS="-arch i386 -arch x86_64"
        export LDFLAGS="$LDFLAGS -arch i386 -arch x86_64"
        export CPP=/usr/bin/cpp
        export CXXCPP=/usr/bin/cpp
        ;;
    esac

    # Note: cmake ignores CPPFLAGS, so also add -I to CFLAGS and CXXFLAGS.
    # Note: have to use -isystem instead of -I to avoid Qt build failure
    # due to accidentally including libevent's event.h
    # via #include "Event.h" on case-insensitive filesystems;
    # see https://sourceforge.net/p/levent/bugs/311/
    case "$opt_prefix" in
    "") bs_warn "bs_set_cflags: mac buildshim for this package did not set opt_prefix";;
    *)
        # Note: Apple cpp doesn't support -isystem, so don't set it ever.
        #export CPPFLAGS="-isystem $opt_prefix/include"
        CFLAGS="$CFLAGS -isystem $opt_prefix/include"
        CXXFLAGS="$CXXFLAGS -isystem $opt_prefix/include"
        LDFLAGS="$LDFLAGS -L$opt_prefix/lib"
        ;;
    esac

    CFLAGS="$CFLAGS $EXTRA_CFLAGS"
    CXXFLAGS="$CXXFLAGS $EXTRA_CXXFLAGS"
}

bs_get_xcode_version() {
    xcodebuild -version | head -1 | awk '{print $2}'
}

# Used by e.g. yobuild's buildshim to select a slightly older version than would be installed by bs_install_xcode.
bs_install_xcode_version() {
    _want_xcode_xy=$1
    # Try to switch xcode version, if needed.
    # Assumes you've installed the right Xcode version and given it an X.Y filename suffix in the Finder.
    xcodebuild -version || sudo xcode-select -switch /Applications/Xcode${_want_xcode_xy}.app
    case $(bs_get_xcode_version) in
    ${_want_xcode_xy}|${_want_xcode_xy}.*) ;;
    *) sudo xcode-select -switch /Applications/Xcode${_want_xcode_xy}.app;;
    esac

    xcodebuild -version
    case $(bs_get_xcode_version) in
    ${_want_xcode_xy}|${_want_xcode_xy}.*) ;;
    *) bs_abort "please install Xcode $_want_xcode_xy";;
    esac
}

bs_install_xcode() {
    # Except for special cases, let's use the most recent xcode supported on each OS.
    case $_os in
    osx107)   bs_install_xcode_version 4.5 ;;
    osx109)   bs_install_xcode_version 5.1 ;;
    osx1010)  bs_install_xcode_version 6.1 ;;
    osx1011)  bs_install_xcode_version 7.1 ;;
    osx1012)  bs_install_xcode_version 8.1 ;;
    osx1013)  bs_install_xcode_version 9.0 ;;
    osx1014)  bs_install_xcode_version 10.1 ;;
    osx1015)  bs_install_xcode_version 11.0 ;;
    osx*)     bs_abort "unsupported os $_os";;
    esac
}

# If you didn't start cygwin from inside a visual studio 2010 command shell,
# use this function to more or less do the same thing.  Fragile.
bs_msvc2010_defaults() {
    echo "Warning: No Visual C++ environment variables found, so making some up."
    echo "Please start cygwin from a Visual Studio Command Prompt instead."
    # Extracted by diffing environment between a cygwin shell started from
    # visual studio 2010 command prompt and a normal cygwin shell.
    export DevEnvDir='C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE'
    # vs2010 uses .net internally
    export Framework35Version=v3.5
    export FrameworkDir=C:\Windows\Microsoft.NET\Framework\
    export FrameworkDIR32=C:\Windows\Microsoft.NET\Framework\
    export FrameworkVersion=v4.0.30319
    export FrameworkVersion32=v4.0.30319
    # boost needs these
    export INCLUDE='C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\INCLUDE;C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\ATLMFC\INCLUDE;C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\include;'
    export LIB='C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\LIB;C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\ATLMFC\LIB;C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\lib;'
    export LIBPATH='C:\Windows\Microsoft.NET\Framework\v4.0.30319;C:\Windows\Microsoft.NET\Framework\v3.5;C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\LIB;C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\ATLMFC\LIB;'

    export PATH='/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/VSTSDB/Deploy:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/Common7/IDE:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/VC/BIN:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/Common7/Tools:/cygdrive/c/Windows/Microsoft.NET/Framework/v4.0.30319:/cygdrive/c/Windows/Microsoft.NET/Framework/v3.5:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/VC/VCPackages:/cygdrive/c/Program Files (x86)/HTML Help Workshop:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/Team Tools/Performance Tools:/cygdrive/c/Program Files (x86)/Microsoft SDKs/Windows/v7.0A/bin/NETFX 4.0 Tools:/cygdrive/c/Program Files (x86)/Microsoft SDKs/Windows/v7.0A/bin:/cygdrive/c/Program Files (x86)/Microsoft DirectX SDK (August 2006)/Utilities/Bin/x86:'$PATH
    export VCINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\'
    export VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 10.0\'
    export WindowsSdkDir='C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\'
}

bs_msvc2013_defaults() {
    echo "Warning: No Visual C++ environment variables found, so making some up."
    echo "Please start cygwin from a Visual Studio Command Prompt instead."
    # Extracted by diffing environment between a cygwin shell started from
    # visual studio 2013 command prompt and a normal cygwin shell.
    export DevEnvDir='C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\'
    export ExtensionSdkDir='C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1\ExtensionSDKs'
    export Framework40Version='v4.0'
    export FrameworkDir='C:\Windows\Microsoft.NET\Framework\'
    export FrameworkDIR32='C:\Windows\Microsoft.NET\Framework\'
    export FrameworkVersion='v4.0.30319'
    export FrameworkVersion32='v4.0.30319'
    # boost needs these
    export INCLUDE='C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\INCLUDE;C:\Program Files (x86)\Windows Kits\8.1\include\shared;C:\Program Files (x86)\Windows Kits\8.1\include\um;C:\Program Files (x86)\Windows Kits\8.1\include\winrt;'
    export LIB='C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\LIB;C:\Program Files (x86)\Windows Kits\8.1\lib\winv6.3\um\x86;'
    export LIBPATH='C:\Windows\Microsoft.NET\Framework\v4.0.30319;C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\LIB;C:\Program Files (x86)\Windows Kits\8.1\References\CommonConfiguration\Neutral;C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1\ExtensionSDKs\Microsoft.VCLibs\12.0\References\CommonConfiguration\neutral;'

    export PATH='/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 12.0/Common7/IDE/CommonExtensions/Microsoft/TestWindow:/cygdrive/c/Program Files (x86)/MSBuild/12.0/bin:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 12.0/Common7/IDE:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 12.0/VC/BIN:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 12.0/Common7/Tools:/cygdrive/c/Windows/Microsoft.NET/Framework/v4.0.30319:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 12.0/VC/VCPackages:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 12.0/Team Tools/Performance Tools:/cygdrive/c/Program Files (x86)/Windows Kits/8.1/bin/x86:/cygdrive/c/Program Files (x86)/Microsoft SDKs/Windows/v8.1A/bin/NETFX 4.5.1 Tools:'$PATH

    export VCINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\'
    export VisualStudioVersion='12.0'
    export VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 12.0\'
    export WindowsSDK_ExecutablePath_x64='C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\x64\'
    export WindowsSDK_ExecutablePath_x86='C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\'
    export WindowsSdkDir='C:\Program Files (x86)\Windows Kits\8.1\'
}

bs_msvc2015_defaults() {
    echo "Warning: No Visual C++ environment variables found, so making some up."
    echo "Please start cygwin from a Visual Studio Command Prompt instead."
    # Extracted by diffing environment between a cygwin shell started from
    # visual studio 2015 command prompt and a normal cygwin shell.
    export DevEnvDir='C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\'
    export Framework40Version='v4.0'
    export FrameworkDir='C:\Windows\Microsoft.NET\Framework\'
    export FrameworkDIR32='C:\Windows\Microsoft.NET\Framework\'
    export FrameworkVersion='v4.0.30319'
    export FrameworkVersion32='v4.0.30319'
    export INCLUDE='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\INCLUDE;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\ATLMFC\INCLUDE;C:\Program Files (x86)\Windows Kits\10\include\10.0.10150.0\ucrt;C:\Program Files (x86)\Windows Kits\NETFXSDK\4.6.1\include\um;C:\Program Files (x86)\Windows Kits\8.1\include\\shared;C:\Program Files (x86)\Windows Kits\8.1\include\\um;C:\Program Files (x86)\Windows Kits\8.1\include\\winrt;'
    export LIB='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\LIB;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\ATLMFC\LIB;C:\Program Files (x86)\Windows Kits\10\lib\10.0.10150.0\ucrt\x86;C:\Program Files (x86)\Windows Kits\NETFXSDK\4.6.1\lib\um\x86;C:\Program Files (x86)\Windows Kits\8.1\lib\winv6.3\um\x86;'
    export LIBPATH='C:\Windows\Microsoft.NET\Framework\v4.0.30319;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\LIB;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\ATLMFC\LIB;C:\Program Files (x86)\Windows Kits\8.1\References\CommonConfiguration\Neutral;\Microsoft.VCLibs\14.0\References\CommonConfiguration\neutral;'
    export PATH='/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE/CommonExtensions/Microsoft/TestWindow:/cygdrive/c/Program Files (x86)/MSBuild/14.0/bin:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE/:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/VC/BIN:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/Tools:/cygdrive/c/Windows/Microsoft.NET/Framework/v4.0.30319:/cygdrive/c/Program Files(x86)/Microsoft Visual Studio 14.0/VC/VCPackages:/cygdrive/c/Program Files (x86)/HTML Help Workshop:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Team Tools/Performance Tools:/cygdrive/c/Program Files (x86)/Windows Kits/8.1/bin/x86:/cygdrive/c/Program Files (x86)/Microsoft SDKs/Windows/v10.0A/bin/NETFX 4.6.1 Tools/:/cygdrive/c/ProgramData/Oracle/Java/javapath:/cygdrive/c/Ruby193/bin:"/cygdrive/c/Program Files (x86)/Microsoft DirectX SDK (August2006)/Utilities/Bin/x86":/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/Wbem:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/:/cygdrive/c/Program Files/WIDCOMM/Bluetooth Software/:/cygdrive/c/Program Files/WIDCOMM/Bluetooth Software/syswow64:c:/Program Files (x86)/Microsoft SQL Server/100/Tools/Binn/:c:/Program Files/Microsoft SQL Server/100/Tools/Binn/:c:/Program Files/Microsoft SQL Server/100/DTS/Binn/:/cygdrive/c/Program Files (x86)/OpenNI/Bin:/cygdrive/c/Program Files (x86)/PrimeSense/NITE/bin:/cygdrive/c/Program Files (x86)/CMake/bin:/cygdrive/c/Program Files/OpenVPN/bin:/cygdrive/c/Program Files (x86)/Windows Kits/8.1/Windows Performance Toolkit/:/cygdrive/c/Program Files (x86)/Java/jre7/bin:/cygdrive/c/Program Files (x86)/Java/jdk1.7.0_25/bin:'$PATH
    echo $PATH
    which cl
    export VCINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\'
    export VisualStudioVersion='14.0'
    export VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 14.0\'
    export WindowsSDK_ExecutablePath_x64='C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\x64\'
    export WindowsSDK_ExecutablePath_x86='C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\'
    export WindowsSdkDir='C:\Program Files (x86)\Windows Kits\8.1\'
}

bs_msvc2015_64_defaults() {
    echo "Warning: No Visual C++ environment variables found, so making some up."
    echo "Please start cygwin from a Visual Studio Command Prompt instead."
    # Extracted by doing 'set' in a visual studio 2015 command prompt,
    # except for Path, which was extracted by then starting cygwin...
    # and removing /bin and /usr/bin from the start, to avoid overloading MS's link.exe.
    # Appended $PATH to restore access to /bin, /usr/bin, and anything else we missed.

    export PATH='/cygdrive/c/Perl64/site/bin:/cygdrive/c/Perl64/bin:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE/CommonExtensions/Microsoft/TestWindow:/cygdrive/c/Program Files (x86)/MSBuild/14.0/bin/amd64:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/VC/BIN/amd64:/cygdrive/c/Windows/Microsoft.NET/Framework64/v4.0.30319:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/VC/VCPackages:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/Tools:/cygdrive/c/Program Files (x86)/HTML Help Workshop:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Team Tools/Performance Tools/x64:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 14.0/Team Tools/Performance Tools:/cygdrive/c/Program Files (x86)/Windows Kits/8.1/bin/x64:/cygdrive/c/Program Files (x86)/Windows Kits/8.1/bin/x86:/cygdrive/c/Program Files (x86)/Microsoft SDKs/Windows/v10.0A/bin/NETFX 4.6.1 Tools/x64:/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/Wbem:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0:/cygdrive/c/Users/buildbot/.dnx/bin:/cygdrive/c/Program Files/Microsoft DNX/Dnvm:/cygdrive/c/Program Files (x86)/Windows Kits/8.1/Windows Performance Toolkit:/cygdrive/c/Program Files/Microsoft SQL Server/130/Tools/Binn:/cygdrive/c/Program Files/Git/cmd:/cygdrive/c/Program Files/CMake/bin:/cygdrive/c/python36:/cygdrive/c/Program Files/nasm':$PATH

    export Framework40Version='v4.0'
    export FrameworkDir='C:\Windows\Microsoft.NET\Framework64'
    export FrameworkVersion='v4.0.30319'
    export FrameworkVersion64='v4.0.30319'
    export INCLUDE='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\INCLUDE;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\ATLMFC\INCLUDE;C:\Program Files (x86)\Windows Kits\10\include\10.0.10240.0\ucrt;C:\Program Files (x86)\Windows Kits\NETFXSDK\4.6.1\include\um;C:\Program Files (x86)\Windows Kits\8.1\include\\shared;C:\Program Files (x86)\Windows Kits\8.1\include\\um;C:\Program Files (x86)\Windows Kits\8.1\include\\winrt;'
    export LIB='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\LIB\amd64;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\ATLMFC\LIB\amd64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.10240.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\NETFXSDK\4.6.1\lib\um\x64;C:\Program Files (x86)\Windows Kits\8.1\lib\winv6.3\um\x64;'
    export LIBPATH='C:\Windows\Microsoft.NET\Framework64\v4.0.30319;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\LIB\amd64;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\ATLMFC\LIB\amd64;C:\Program Files (x86)\Windows Kits\8.1\References\CommonConfiguration\Neutral;\Microsoft.VCLibs\14.0\References\CommonConfiguration\neutral;'
    export VCINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\'
    export VisualStudioVersion='14.0'
    export VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 14.0\'
    export WindowsSdkDir='C:\Program Files (x86)\Windows Kits\8.1\'
    export WindowsSDK_ExecutablePath_x64='C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\x64\'
    export WindowsSDK_ExecutablePath_x86='C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\'
}

bs_msvc2017_defaults() {
    echo "Warning: No Visual C++ environment variables found, so making some up."
    echo "Please start cygwin from a Visual Studio Command Prompt instead."
    # Extracted by diffing environment between a cygwin shell started from
    # visual studio 2017 community command prompt and a normal cygwin shell.
    export __DOTNET_ADD_32BIT='1'
    export __DOTNET_ADD_64BIT='1'
    export __DOTNET_PREFERRED_BITNESS='64'
    export __VSCMD_PREINIT_PATH='C:\Perl64\site\bin;C:\Perl64\bin;C:\Program Files (x86)\Intel\Intel(R) Management Engine Components\iCLS\;C:\Program Files\Intel\Intel(R) Management Engine Components\iCLS\;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Windows\System32\OpenSSH\;C:\Program Files (x86)\Intel\Intel(R) Management Engine Components\DAL;C:\Program Files\Intel\Intel(R) Management Engine Components\DAL;C:\Users\buildbot\AppData\Local\Microsoft\WindowsApps;'
    export CommandPromptType='Cross'
    export DevEnvDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\'
    export ExtensionSdkDir='C:\Program Files (x86)\Microsoft SDKs\Windows Kits\10\ExtensionSDKs'
    export Framework40Version='v4.0'
    export FrameworkDir='C:\Windows\Microsoft.NET\Framework64\'
    export FrameworkDir32='C:\Windows\Microsoft.NET\Framework\'
    export FrameworkDir64='C:\Windows\Microsoft.NET\Framework64\'
    export FrameworkVersion='v4.0.30319'
    export FrameworkVersion32='v4.0.30319'
    export FrameworkVersion64='v4.0.30319'
    export INCLUDE='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\ATLMFC\include;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\include;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\ucrt;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\shared;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\um;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\winrt;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\cppwinrt'
    export LIB='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\ATLMFC\lib\x86;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x86;C:\Program Files (x86)\Windows Kits\10\lib\10.0.17763.0\ucrt\x86;C:\Program Files (x86)\Windows Kits\10\lib\10.0.17763.0\um\x86;'
    export LIBPATH='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\ATLMFC\lib\x86;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x86;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x86\store\references;C:\Program Files (x86)\Windows Kits\10\UnionMetadata\10.0.17763.0;C:\Program Files (x86)\Windows Kits\10\References\10.0.17763.0;C:\Windows\Microsoft.NET\Framework64\v4.0.30319;'
    export ORIGINAL_PATH='/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.16.27023/bin/HostX64/x86:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.16.27023/bin/HostX64/x64:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/VC/VCPackages:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/TestWindow:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/TeamFoundation/Team Explorer:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/MSBuild/15.0/bin/Roslyn:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Team Tools/Performance Tools:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/Shared/Common/VSPerfCollectionTools:/cygdrive/c/Program Files (x86)/Windows Kits/10/bin/10.0.17763.0/x64:/cygdrive/c/Program Files (x86)/Windows Kits/10/bin/x64:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/MSBuild/15.0/bin:/cygdrive/c/Windows/Microsoft.NET/Framework64/v4.0.30319:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/Tools:/cygdrive/c/Perl64/site/bin:/cygdrive/c/Perl64/bin:/cygdrive/c/Program Files (x86)/Intel/Intel(R) Management Engine Components/iCLS:/cygdrive/c/Program Files/Intel/Intel(R) Management Engine Components/iCLS:/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/Wbem:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0:/cygdrive/c/Windows/System32/OpenSSH:/cygdrive/c/Program Files (x86)/Intel/Intel(R) Management Engine Components/DAL:/cygdrive/c/Program Files/Intel/Intel(R) Management Engine Components/DAL:/cygdrive/c/Users/buildbot/AppData/Local/Microsoft/WindowsApps:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin:/cygdrive/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja'
    # Careful, if user put a special directory on path ahead of /bin, preserve that
    export PATH="${ORIGINAL_PATH}:$PATH"
    export Platform='x86'
    export PreferredToolArchitecture='x64'
    export PROMPT='$P$G'
    export UCRTVersion='10.0.17763.0'
    export UniversalCRTSdkDir='C:\Program Files (x86)\Windows Kits\10\'
    export VCIDEInstallDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\VC\'
    export VCINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\'
    export VCToolsInstallDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\'
    export VCToolsRedistDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Redist\MSVC\14.16.27012\'
    export VCToolsVersion='14.16.27023'
    export VisualStudioVersion='15.0'
    export VS150COMNTOOLS='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\'
    export VSCMD_ARG_app_plat='Desktop'
    export VSCMD_ARG_HOST_ARCH='x64'
    export VSCMD_ARG_TGT_ARCH='x86'
    export VSCMD_VER='15.9.3'
    export VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\'
    export WindowsLibPath='C:\Program Files (x86)\Windows Kits\10\UnionMetadata\10.0.17763.0;C:\Program Files (x86)\Windows Kits\10\References\10.0.17763.0'
    export WindowsSdkBinPath='C:\Program Files (x86)\Windows Kits\10\bin\'
    export WindowsSdkDir='C:\Program Files (x86)\Windows Kits\10\'
    export WindowsSDKLibVersion='10.0.17763.0\'
    export WindowsSdkVerBinPath='C:\Program Files (x86)\Windows Kits\10\bin\10.0.17763.0\'
    export WindowsSDKVersion='10.0.17763.0\'
}

bs_msvc2017_64_defaults() {
    echo "Warning: No Visual C++ environment variables found, so making some up."
    echo "Please start cygwin from a Visual Studio Command Prompt instead."
    # Extracted by diffing environment between a cygwin shell started from
    # visual studio 2017 community command prompt and a normal cygwin shell.
    export __DOTNET_ADD_64BIT='1'
    export __DOTNET_PREFERRED_BITNESS='64'
    export __VSCMD_PREINIT_PATH='C:\Program Files\Python37\Scripts\;C:\Program Files\Python37\;C:\Perl64\site\bin;C:\Perl64\bin;C:\Program Files (x86)\Intel\Intel(R) Management Engine Components\iCLS\;C:\Program Files\Intel\Intel(R) Management Engine Components\iCLS\;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Windows\System32\OpenSSH\;C:\Program Files (x86)\Intel\Intel(R) Management Engine Components\DAL;C:\Program Files\Intel\Intel(R) Management Engine Components\DAL;C:\Program Files\CMake\bin;C:\Program Files\Git\cmd;c:\opt\ninja;C:\Ruby24-x64\bin;C:\Users\buildbot\AppData\Local\Microsoft\WindowsApps'
    export CommandPromptType='Native'
    export DevEnvDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\'
    export ExtensionSdkDir='C:\Program Files (x86)\Microsoft SDKs\Windows Kits\10\ExtensionSDKs'
    export Framework40Version='v4.0'
    export FrameworkDir='C:\Windows\Microsoft.NET\Framework64\'
    export FrameworkDir64='C:\Windows\Microsoft.NET\Framework64\'
    export FrameworkVersion='v4.0.30319'
    export FrameworkVersion64='v4.0.30319'
    export INCLUDE='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\ATLMFC\include;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\include;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\ucrt;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\shared;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\um;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\winrt;C:\Program Files (x86)\Windows Kits\10\include\10.0.17763.0\cppwinrt'
    export LIB='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\ATLMFC\lib\x64;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.17763.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.17763.0\um\x64;'
    export LIBPATH='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\ATLMFC\lib\x64;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x64;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x86\store\references;C:\Program Files (x86)\Windows Kits\10\UnionMetadata\10.0.17763.0;C:\Program Files (x86)\Windows Kits\10\References\10.0.17763.0;C:\Windows\Microsoft.NET\Framework64\v4.0.30319;'
    export ORIGINAL_PATH="\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.16.27023/bin/HostX64/x64:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/VC/VCPackages:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/TestWindow:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/TeamFoundation/Team Explorer:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/MSBuild/15.0/bin/Roslyn:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Team Tools/Performance Tools/x64:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Team Tools/Performance Tools:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/Shared/Common/VSPerfCollectionTools/x64:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/Shared/Common/VSPerfCollectionTools:\
$DRIVEC/Program Files (x86)/HTML Help Workshop:\
$DRIVEC/Program Files (x86)/Windows Kits/10/bin/10.0.17763.0/x64:\
$DRIVEC/Program Files (x86)/Windows Kits/10/bin/x64:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/MSBuild/15.0/bin:\
$DRIVEC/Windows/Microsoft.NET/Framework64/v4.0.30319:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/Tools:\
$DRIVEC/Program Files/Python37/Scripts:\
$DRIVEC/Program Files/Python37:\
$DRIVEC/Perl64/site/bin:\
$DRIVEC/Perl64/bin:\
$DRIVEC/Program Files (x86)/Intel/Intel(R) Management Engine Components/iCLS:\
$DRIVEC/Program Files/Intel/Intel(R) Management Engine Components/iCLS:\
$DRIVEC/Windows/system32:\
$DRIVEC/Windows:\
$DRIVEC/Windows/System32/Wbem:\
$DRIVEC/Windows/System32/WindowsPowerShell/v1.0:\
$DRIVEC/Windows/System32/OpenSSH:\
$DRIVEC/Program Files (x86)/Intel/Intel(R) Management Engine Components/DAL:\
$DRIVEC/Program Files/Intel/Intel(R) Management Engine Components/DAL:\
$DRIVEC/Program Files/CMake/bin:\
$DRIVEC/Program Files/Git/cmd:\
$DRIVEC/opt/ninja:\
$DRIVEC/Ruby24-x64/bin:\
$DRIVEC/Users/buildbot/AppData/Local/Microsoft/WindowsApps:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin:\
$DRIVEC/Program Files (x86)/Microsoft Visual Studio/2017/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja"
    # Careful, if user put a special directory on path ahead of /bin, preserve that
    export PATH="${ORIGINAL_PATH}:$PATH"
    export Platform='x64'
    export PROMPT='$P$G'
    export UCRTVersion='10.0.17763.0'
    export UniversalCRTSdkDir='C:\Program Files (x86)\Windows Kits\10\'
    export VCIDEInstallDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\VC\'
    export VCINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\'
    export VCToolsInstallDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\'
    export VCToolsRedistDir='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Redist\MSVC\14.16.27012\'
    export VCToolsVersion='14.16.27023'
    export VisualStudioVersion='15.0'
    export VS150COMNTOOLS='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\'
    export VSCMD_ARG_app_plat='Desktop'
    export VSCMD_ARG_HOST_ARCH='x64'
    export VSCMD_ARG_TGT_ARCH='x64'
    export VSCMD_VER='15.9.4'
    export VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\'
    export WindowsLibPath='C:\Program Files (x86)\Windows Kits\10\UnionMetadata\10.0.17763.0;C:\Program Files (x86)\Windows Kits\10\References\10.0.17763.0'
    export WindowsSdkBinPath='C:\Program Files (x86)\Windows Kits\10\bin\'
    export WindowsSdkDir='C:\Program Files (x86)\Windows Kits\10\'
    export WindowsSDKLibVersion='10.0.17763.0\'
    export WindowsSdkVerBinPath='C:\Program Files (x86)\Windows Kits\10\bin\10.0.17763.0\'
    export WindowsSDKVersion='10.0.17763.0\'
}

# Make sure environment variables are already set for Visual C++,
# or failing that, make a good guess.
bs_vcvars32() {
    case $PATH in
    *"Visual Studio 10"*)
        export YB_COMPILERNAME=msvc2010;;
    *"Visual Studio 12"*)
        export YB_COMPILERNAME=msvc2013;;
    *"Visual Studio 14"*)
        export YB_COMPILERNAME=msvc2015;;
    *"Microsoft Visual Studio/2017"*)
        export YB_COMPILERNAME=msvc2017;;
    *Visual*)
        bs_abort "Unknown version of visual C++ on path";;
    *)
        case "$opt_toolchain" in
        msvc2010) bs_msvc2010_defaults;;
        msvc2013) bs_msvc2013_defaults;;
        msvc2015) bs_msvc2015_defaults;;
        msvc2017) bs_msvc2017_defaults;;
        *) bs_abort "unknown opt_toolchain $opt_toolchain";;
        esac
        ;;
    esac
    if ! yes | cl '/?' > /dev/null 2>&1
    then
        bs_abort "Cannot run visual c++"
    fi
}

bs_vcvars64() {
    case $PATH in
    *"Visual Studio 14"*)
        export YB_COMPILERNAME=msvc2015;;
    *"Microsoft Visual Studio/2017"*)
        export YB_COMPILERNAME=msvc2017;;
    *Visual*)
        bs_abort "Unknown version of visual C++ on path";;
    *)
        case "$opt_toolchain" in
        msvc2015) bs_msvc2015_64_defaults;;
        msvc2017) bs_msvc2017_64_defaults;;
        *) bs_abort "unknown opt_toolchain $opt_toolchain";;
        esac
        ;;
    esac
    if ! yes | cl '/?' > /dev/null 2>&1
    then
        bs_abort "Cannot run visual c++"
    fi
}

bs_vcvars() {
    case $1 in
    32) bs_vcvars32;;
    64) bs_vcvars64;;
    *) bs_abort "bs_vcvars: unknown width $1";;
    esac
}

bs_kludge_install_modern_git() {
    # Get modern git
    if git submodule --help | grep -q deinit
    then
        # Maybe git lfs needs git 2.9 or later to avoid
        # https://gitlab.oblong.com/platform/ob-repobot/issues/45
        local v=$(git --version | awk '{print $3}')
        case $v in
        2.9*|3*) return 0;;
        esac
    fi

    case $_os in
    ubu*)
        bs_add_ppa git-core ppa:git-core/ppa
        $SUDO apt-get $apt_quiet update
        ;;
    esac
    case $_os in
    ubu*)
        $SUDO apt-get $apt_quiet install -y git
        ;;
    osx*)
        brew upgrade git || brew install git
        ;;
    esac
}

# For things that don't need actual security, rot13 makes things less obvious.
bs_rot13() {
    tr a-zA-Z/+0. n-za-mN-ZA-M+/.0
}

# Kludge: buildshims for projects that use git lfs should call this in do_patch
# to work around lack of git lfs support in buildbot proper
bs_kludge_init_git_lfs() {
    if ! git lfs env > /dev/null
    then
        bs_kludge_install_modern_git
        case $_os in
        ubu12*|ubu14*)
            rm -rf git-lfs*.deb
            DPKGARCH=$(dpkg --print-architecture)
            wget http://obdumper.oblong.com/software/git-lfs/$_os/git-lfs_1.2.1_$DPKGARCH.deb ||
                wget http://obdumper.oblong.com/software/git-lfs/$_os/git-lfs_1.2.1_i386.deb
            sudo dpkg -i git-lfs_1.2.1_*.deb
            rm -rf git-lfs*.deb
            ;;
        ubu*)
            # We have added git-lfs 2.0.2 to our local ubuntu 16.04 repository,
            # see https://gitlab.oblong.com/platform/git-lfs   Longer term,
            # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=792075
            sudo apt-get $apt_quiet update
            sudo apt-get install $apt_quiet -y git-lfs
            ;;
        osx*)
            brew upgrade git-lfs || brew install git-lfs
            ;;
        *)  bs_abort "not implemented"
            ;;
        esac
    fi
    git lfs install --local
    git lfs pull
}


# Kludge: buildshims for projects that use submodules should call this in do_patch
# to work around http://trac.buildbot.net/ticket/3575
bs_kludge_init_submodule_on_try_build() {
    if test -f .gitmodules && bs_is_try_build
    then
        bs_warn "Initializing git submodules to work around http://trac.buildbot.net/ticket/3575"
        bs_warn "Assuming deps is all submodules... removing and reinitializing"
        if ! git submodule --help | grep -q deinit
        then
            bs_add_ppa git-core ppa:git-core/ppa
            $SUDO apt-get $apt_quiet update
            apt-cache policy git
            $SUDO apt-get $apt_quiet remove -y git || true
            $SUDO apt-get $apt_quiet install -y git || true
            apt-cache policy git
        fi
        # Undo all old submodules
        if git submodule foreach 'echo $path' | grep -v "Entering '" > old-submodules.tmp
        then
            echo "Removing and deinitting old modules"
            cat  old-submodules.tmp
            rm -rf $(cat old-submodules.tmp)
            git submodule deinit .
            git checkout -- $(cat old-submodules.tmp)
        fi
        rm old-submodules.tmp
        # Do new submodules
        git submodule init
        git submodule update
        git submodule status
    fi
}

# Adds magic strings to the logs so that SimpleConfig.py
# adds a link for this build step (like artifacts links).
# Note that this assumes that bs_upload will be called to
# upload the target to the expected location.
bs_add_log_link() {
    name=$1
    url=$2
    kind=$(bs_intuit_buildtype $*)
    base_url=repobot/$kind/builds/$bs_artifactsubdir
    echo "buildbot-url:$name|$base_url/$url"
}

bs_upload() {
    (
    # note: buildername and buildnumber are encoded in $bs_artifactsubdir on entry, see bs_get_artifact_subdir
    # note: $apt_name, $apt_codename and $apt_section will be sanity checked by obs apt-pkg-add
    # note: if BS_UNPACK_IT is set and it is a tarball, unpack it after uploading.
    apt_name="$1"      # deprecated; see below
    shift
    apt_section="$1"   # "main" or "non-free"
    shift

    kind=$(bs_intuit_buildtype $*)
    case $apt_name in
    fakekind) ;;
    $kind) bs_warn "bs_upload: 1st arg is deprecated, please pass 'fakekind' instead";;
    *) bs_abort "bs_upload: hrm, bs_intuit_buildtype disagrees with hardcoded value, who is right?";;
    esac
    apt_name=$kind

    # First upload the artifacts and their checksums
    shasum $* | sed 's, .*/,  ,' | tee sha1sums.txt
    # FIXME: we assume $bs_repotop is same on local and remote machine, this may need fixing
    builds_dest=$bs_repotop/$apt_name/builds/$bs_artifactsubdir

    case "$version_patchnum" in
    "") version_patchnum=$(bs_get_changenum_git);;
    esac

    bs_create_empty_dir_on_master $builds_dest
    case $MASTER in
    localhost)
        cp $* sha1sums.txt $builds_dest
        rm -f $builds_dest/../latest && ln -s $builds_dest $builds_dest/../latest
        ;;
    *)
        scp -o StrictHostKeyChecking=no -p $* sha1sums.txt $bs_upload_user@${MASTER}:$builds_dest
        ssh -o StrictHostKeyChecking=no $bs_upload_user@${MASTER} "cd $builds_dest && rm -f ../latest && ln -s $builds_dest ../latest"
        ;;
    esac

    # Then do anything needed on the server
    # fixme: this doesn't allow mixing two different file types yet
    case $1 in
    *.deb)
       # Publish debs to the apt repo if appropriate
       if ! bs_no_publish
       then
        case "$apt_name" in
        "rel")
            echo "Checking whether version_patchnum $version_patchnum and name $1 are ok to publish to rel"
            case "$version_patchnum" in
            "0") ;;
            *)
                    case "$1" in
                    # Note: should no longer need to add projects to whitelist here, now that
                    # bs_intuit_buildtype{,_deps} implement the simple "builds on rel tags are rel" policy.
                    # If you do need to override the default policy, see bs_get_project_buildtype_override
                    *libpdl-graphics-gnuplot-perl*) bs_warn "Special case for libpdl-graphics-gnuplot-perl: allowing untagged build (version_patchnum $version_patchnum != 0).  But don't let me catch you again.";;
                    *pdl*) bs_warn "oh, man, are we still using pdl?";;
                    *)   bs_abort "Not adding release package to apt repo, since version_patchnum ($version_patchnum) != 0; did this get tagged properly?"; return;;
                    esac
            esac
            ;;
        esac
        # It's appropriate; copy into the apt repo.
        # FIXME: be less fragile
        # Look up the codename for the current OS.  If cross-building, set this manually before calling.
        if test ! "$apt_codename"
        then
            apt_codename="$(bs_os_codename $_os)"   # 'precise', 'trusty', or 'xenial'
        fi
        # FIXME: gaah.  uberbau makes this tricky.  bs_repotop must match between local and remote.
        case $MASTER in
        localhost)
            obs apt-pkg-add $apt_name-$apt_codename $apt_codename $builds_dest/*.deb
            ;;
        *)
            ssh -n -o StrictHostKeyChecking=no $bs_upload_user@$MASTER "cd $builds_dest && bs_repotop=$bs_repotop obs apt-pkg-add '$apt_name'-'$apt_codename' '$apt_codename' *.deb"
            ;;
        esac

        # Shiny new apt upload mechanism in parallel with old one for now.
        # FIXME: doesn't support bau yet.  And nobody's using it anyway.
        #bs_arepo_upload $apt_codename $apt_name $*

        # Only fire the dependency hook if we actually publish (else try builders will sneak into the list of things to trigger)
        bs_deps_hook $*
       fi
        ;;
    *.tar.gz|*.tgz)
        if test "$BS_UNPACK_IT"
        then
            for tarball
            do
                case $MASTER in
                localhost)
                    tar -C $builds_dest -xzf $tarball
		    if test -n "$BS_NUKE_TARBALL"
		    then
		        # For certain uploads, keeping the tarball almost doubles disk usage
		        rm -f $builds_dest/$tarball
		    fi
                    ;;
                *)
                    ssh -n -o StrictHostKeyChecking=no $bs_upload_user@$MASTER "cd $builds_dest; tar -xzf $tarball"
		    if test -n "$BS_NUKE_TARBALL"
		    then
		        # For certain uploads, keeping the tarball almost doubles disk usage
		        ssh -n -o StrictHostKeyChecking=no $bs_upload_user@$MASTER "cd $builds_dest; rm -f $tarball"
		    fi
                    ;;
                esac
            done
        fi
    esac
    )
}

# Move debian build results from parent directory to given destination (default: . )
# (Moves .buildinfo, .build, and .changes files, too, if present.)
bs_move_debs_to()
{
  local dest=${1:-.}
  local file basefile file2 suffix

  # Currently only works for builds which list results in debian/files,
  # e.g. were done with standard debian tools, not fpm etc.
  # Should we hoist search out of bs_upload_debs and into here?
  if ! test -f debian/files
  then
    bs_abort "bs_move_debs_to: debian/files not found, cannot move build results."
  fi

  # Don't just guess -- look at debian/files for the files to move.
  # Primarily .deb files, but with reproducible-builds.org patches, it also lists .buildinfo.
  while read file _
  do
    mv ../$file ${dest}/
    # Also grab the .build and .changes files so they don't clutter the parent directory
    basefile=${file%.deb}
    for suffix in build changes
    do
      file2=$basefile.$suffix
      if test -f ../$file2
      then
        mv ../$file2 ${dest}/
      fi
    done
  done < debian/files
}

bs_upload_debs() {
    local d
    for d in . .. debbuild btmp btmp/_CPack_Packages no-deb-found
    do
        if ls $d/*.deb
        then
            break
        fi
    done
    if test $d = no-deb-found
    then
        bs_abort "No packages found to upload"
    fi

    # Don't upload synthetic build dependency packages
    rm -f $d/*-build-deps*deb || true

    local status=0
    if test -n "$GITLAB_CI"
    then
      # Upload to both buildhost4 and buildhost5 from gitlab builds.
      # TODO: remove this block once buildhost4 is truly gone.

      # Don't use 'if' here, else bs_abort inside bs_upload won't abort.
      # See http://mywiki.wooledge.org/BashFAQ/105
      # but in short, 'set -e' and 'if' don't get along
      MASTER=buildhost4.oblong.com bs_upload fakekind non-free $d/*.deb
      test $? != 0 && status=$?
      MASTER=buildhost5.oblong.com bs_upload fakekind non-free $d/*.deb
      test $? != 0 && status=$?
    else
      bs_upload fakekind non-free $d/*.deb
      test $? != 0 && status=$?
    fi
    if test $status != 0
    then
      bs_abort "upload failed, and it didn't abort for some reason"
    fi

    if ! test "$BS_KEEP_IT"
    then
        # When run in a docker-rich environment, you might
        # be uploading things owned by root, sigh.
        $SUDO rm -f $d/*.deb
    fi
}

ASTOR_PACKAGE_SERVERS="git.oblong.com"

bs_astor_upload() {
  if test $# != 1
  then
    bs_abort "bs_astor_upload: please a package name to upload.  (You gave $*)"
  fi
  _mypkgname=$1

  if bs_no_publish
  then
     bs_warn "bs_astor_upload: bs_no_publish true, not uploading (probably a try build)"
     return 0
  fi

  f="${_mypkgname}_*.deb"
  if ! ls $f
  then
     f="${_mypkgname}[0-9]*_*.deb"
  fi
  if ! ls $f
  then
     f="${_mypkgname}*.deb"
  fi
  if ! ls $f
  then
    bs_abort "bs_astor_upload: could not find $f to upload.  (Are you in the right directory?)"
  fi

  dir=/ob/dumper/astor/packages/
  for PACKAGE_SERVER in $ASTOR_PACKAGE_SERVERS
  do
    # jshrake: do not remove old packages -- just pile into $dir
    ssh -n ${PACKAGE_SERVER} "mkdir -p $dir"
    scp $f ${PACKAGE_SERVER}:$dir
  done
}

# Usage: bs_install_zip project X.Y
# Downloads and unpacks the newest build resuilts for branch/version X.Y of given project
# FIXME: remove this.  It's only used by one buildshim.
bs_install_zip() {
    depname=$1
    xy=$2
    base="${3:-/cygdrive/c}"
    rm -f ${depname}*${xy}*.zip
    micro=$(ssh -n $(bs_get_install_sshspec) "cd $bs_install_root/$depname/$_os/$xy; ls | sort -n | tail -n 1")
    patch=$(ssh -n $(bs_get_install_sshspec) "cd $bs_install_root/$depname/$_os/$xy/$micro; ls | sort -n | tail -n 1")
    scp $(bs_get_install_sshspec):$bs_install_root/$depname/$_os/$xy/$micro/$patch/${depname}*.zip .
    # And now the scary part.  First, check for file (not directory) overwrites.
    if ! zipinfo -1 ${depname}*zip | grep -v '/$' | perl -e 'while (<STDIN>) { chomp; warn "/$_ already exists" if -f "$base/$_"; }'
    then
        bs_abort "cannot install ${depname}, file conflict"
    fi
    # Whew.  OK, install away.
    unzip -o ${depname}*${xy}*.zip -d "$base" 2>&1
}

# Usage: bs_uninstall project X.Y
bs_uninstall() {
    _depname=$1
    _xy=$2
    f=${_depname}*${_xy}*.tar.gz
    if test -f $f
    then
        echo Uninstalling $f
        tar -tzf $f |
            grep -v '/$' |
            sudo perl -e 'while(<STDIN>) { chomp; if (-f "/$_") { print "Deleting /$_\n"; unlink("/$_") || warn "cannot delete /$_\n";} }'
        rm $f
    fi
}

# Get access to the appropriate package repo(s) which contains the gspeak we need
# Also make sure debian packaging tools are installed
# Uses globals '$gspeak' and '$version' to decide whether to access dev repo
# FIXME: add Redhat support
bs_use_package_repo() {

    if ! test "$version"
    then
        bs_abort "no version set"
    fi

    kind=$(bs_intuit_buildtype_deps)
    if test $kind = dev
    then
        echo "'git describe' and/or gspeak version shows this build should have access to dev repo"
        want_dev=dev
    else
        echo "'git describe' and/or gspeak version shows this build should have NOT access to dev repo"
        want_dev=""
    fi

    # Refer to the repobot
    local top
    apt_codename="$(bs_os_codename $_os)"   # 'precise', 'trusty', or 'xenial'
    case "$MASTER" in
    localhost)
       cp "$bs_repotop"/repo.pubkey /tmp/repo.key.$$;  top=$bs_repotop;;
    *)
       if ! wget --version > /dev/null; then $SUDO apt-get $apt_quiet install -y wget; fi
       wget -q http://$MASTER/oblong.key -O /tmp/repo.key.$$; top=$bs_repodir;;
    esac
    dirs=""
    for repo in $want_dev rel
    do
        dirs="$dirs $top/$repo-$apt_codename/apt"
    done
    bs_apt_server_add $MASTER /tmp/repo.key.$$ $dirs
    rm /tmp/repo.key.$$

    case $_os in
    ubu1204)
        # FIXME: need to frob different apt if APT_CONFIG?
        # oblong-v8 needs jq, which is in precise-backports on 12.04
        # Maybe we should just always enable backports...
        if ! grep -v '^#' /etc/apt/sources.list | grep backports
        then
            echo "deb http://ubuntu.oblong.com/ precise-backports main restricted universe multiverse" |
                 sudo tee -a /etc/apt/sources.list
        fi
        ;;
    esac

    # Install debuild, mk-build-deps, and their runtime dependencies
    if ! mk-build-deps --version > /dev/null || test "$(which equivs-build)" = ""
    then
        $SUDO apt-get $apt_quiet install -y equivs devscripts build-essential
    fi
}

# Install build deps for packages the debian way
bs_apt_install_deps() {
    # Don't accumulate dependencies from past runs
    bs_deps_clear

    bs_use_package_repo

    # Quick preview of problems... doesn't obey version numbers, so make it nonfatal
    # This can't detect indirect problems
    if ! LC_ALL=C LANG=C dpkg-checkbuilddeps > deps.out 2>&1
    then
        sed -i 's/error: //;s/dpkg-checkbuilddeps: Unmet build dependencies://' deps.out
        wc deps.out
        cat deps.out | tr ' ' '\012' | sort -u | grep '[a-zA-Z]' | egrep -v '\||\(|\)' > deps2.out
        wc deps2.out
        if egrep '\||\(|\)' deps.out
        then
            echo "Early dependency check is only approximate, since I don't know how to handle alternatives or versions"
            apt-cache -q=0 policy $(cat deps2.out) 2>&1 || true
        else
            # check all deps in detail
            apt-cache -q=0 policy $(cat deps.out) 2>&1 || true
        fi
    fi
    rm -f deps.out deps2.out

    # Download and install dependencies.  Don't plotz if some other job interferes by updating index at same time.
    tries=3
    while true
    do
        # If installing from a file repo, use --allow-unauthenticated?
        #sudo mk-build-deps -i -t "apt-get -y --allow-unauthenticated"

        # Want exit status of mk-build-deps, so can't pipe its output to a program
        if yes | $SUDO DEBIAN_FRONTEND=noninteractive LC_ALL=C LANG=C mk-build-deps -i > mk-build-deps.log 2>&1 && ! grep "E: Failed" < mk-build-deps.log
        then
            # We wanted to use tee, but we couldn't, so output it here to both places.
            cat mk-build-deps.log | bs_deps_append_log
            cat mk-build-deps.log
            break
        fi
        cat mk-build-deps.log
        # This happens frequently, usually because we're indexing our own apt repo
        tries=$(expr $tries - 1)
        if test $tries -le 0
        then
            bs_abort "Too many retries trying to download dependencies"
        fi
        echo "Downloading dependencies failed, waiting for apt repo to stabilize..."
        sleep 60
        $SUDO apt-get $apt_quiet update || true
    done
    rm -f mk-build-deps.log
    dpkg-checkbuilddeps
    # Have to remove to avoid error in dpkg-source
    rm -f *-build-deps*.deb
    echo "FIXME: cleaning up after old builds to avoid uploading stale crud (this should not be a side effect of bs_apt_install_deps, but it was easy to put there)"
    rm -rf *.deb ../*.deb debbuild btmp || true

    # Work around https://bugs.launchpad.net/ubuntu/+bug/1557836
    if grep -e -R /usr/lib/x86_64-linux-gnu/pkgconfig/gnutls.pc
    then
        bs_warn "KLUDGE: working around illegal option in gnutls.pc"
        sudo sed -i.bak -e 's,-R/usr/lib/x86_64-linux-gnu,,' /usr/lib/x86_64-linux-gnu/pkgconfig/gnutls.pc
    fi

    echo "Disk usage after installing deps:"
    df / /home || true
}

# Helper to add a PPA repository
# Usage:
#   bs_add_ppa local-name-prefix ppa-spec
# e.g.
#   bs_add_ppa openrave ppa:openrave/release
bs_add_ppa() {
    if ! test -s /etc/apt/sources.list.d/"$1"*.list
    then
        # Requires a ppa, since assimp-dev 3.x is not shipped with Ubuntu < 14.04
        if ! test $(which add-apt-repository 2> /dev/null)
        then
            $SUDO apt-get $apt_quiet update
            case $_os in
            ubu1204)
                $SUDO apt-get $apt_quiet install -y python-software-properties;;
            *)
                $SUDO apt-get $apt_quiet install -y software-properties-common;;
            esac
        fi
        $SUDO add-apt-repository -y $2
    fi
}

bs_rm_ppa() {
    if test -s /etc/apt/sources.list.d/"$1"*.list
    then
        $SUDO add-apt-repository -r -y $2
        $SUDO rm -f /etc/apt/sources.list.d/"$1"*.list
    fi
}

# Initialize variables that work even when there's no package, and are needed by above functions
_os=$(bs_detect_os)
case "$BAU_VERBOSE" in
1) set -x; apt_quiet="";;
*) set +x; apt_quiet="-q";;
esac
ncores=$(bs_detect_ncores)

# Initialization that only works when in the context of building a package
bs_pkg_init() {
    case $_os in
    osx*)
        # Check for https://gitlab.oblong.com/platform/ob-repobot/issues/37
        if ! test -L /etc
        then
            bs_abort "/etc is not a symlink.  Something has broken this mac (probably bs_install kipple; bs_install doesn't handle /etc right if wrong tar executed).  Reboot single-user and fix the symlink."
        fi
        ;;
    esac

    # Read metadata from buildbot or gitlab-ci
    bs_artifactsubdir="$(bs_get_artifact_subdir)"
    #echo bs_artifactsubdir is $bs_artifactsubdir >&2

    version=$(bs_get_version_git)
    parallel="-j$ncores"
    bs_platform_workarounds

    # split $version into major.minor.micro.nano-suffix
    version_prefix=${version%%-*}     # remove longest suffix that starts with -
    version_suffix=
    case $version in
    *-*) version_suffix=${version##*-} ;;    # remove longest prefix that ends with -
    esac
    version_major=$(echo $version_prefix | cut -d. -f1)
    version_minor=$(echo $version_prefix | cut -d. -f2)
    version_micro=$(echo $version_prefix | cut -d. -f3)
    version_nano=$(echo $version_prefix | cut -d. -f4)
    test "$version_micro" = "" && version_micro=0
    if test $version = $version_major.$version_minor.$version_micro.$version_nano
    then
        echo "wow, a four-component version number.  Careful, something might break."
    elif test $version != $version_major.$version_minor.$version_micro && test $version != $version_major.$version_minor
    then
        # Re-enable this when all uses are fixed
        #bs_abort "Failed to parse $version into major.minor.micro"
        echo "Warning: Failed to parse $version into major.minor.micro"
    fi
    version_patchnum=$(bs_get_changenum_git)
}

# If you want to use this without a package, set _bs_no_pkg=1
# FIXME: make packages call bs_pkg_init explicitly, then get rid of _bs_no_pkg
case $_bs_no_pkg in
"") bs_pkg_init ;;
*) ;;
esac
