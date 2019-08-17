#!/bin/sh
set -e

echo "ob-remove.sh: Uninstalling all oblong-related packages (except possibly obs, bau, and ruby gems)."
echo "Options:"
echo "--undev: also remove (nearly) all '-dev' packages."
echo "--autoremove: also remove no-longer-needed packages."
echo ""

opt_undev=false
opt_autoremove=${opt_autoremove:-false}
while test "$1" != ""
do
  case "$1" in
  --undev) opt_undev=true;;
  --autoremove) opt_autoremove=true;;
  *) echo "Unknown arg $1"; exit 1;;
  esac
  shift
done

case "$BAU_VERBOSE" in
1) set -x;;
*) set +x;;
esac

if ! test -w /
then
    echo "This script must be run as root."
    exit 1
fi
if ! grep -i ubuntu /etc/issue
then
    echo "This script is only for Ubuntu at the moment, sorry."
    exit 1
fi

# set $opt_rubytoo to anything if you want to remove all ruby gems

# Regular expression for packages to remove
blacklist_re="g-speak|oblong|mezzanine|whiteboard|corkboard|ob-http-ctl|libpdl-opencv-perl|libpdl-linearalgebra-perl|libpdl-graphics-gnuplot-perl|ob-awesomium|build-deps|depdemo"

# Regular expression for packages to not remove, even though they are may be from oblong
# The mesa/libgbm1/libxatracker2 entries are to avoid removing build products of oblong-mesa
# Keep this list in sync with the one in bs_apt_uninstall_deps
whitelist_re="bzip2|oblong-obs|-mesa|mesa-|libgbm1|libxatracker2|[^g]udev|systemd|ubuntu-keyring"

OLDPKGS=$(dpkg-query -l | egrep -i "$blacklist_re" | awk '{print $2}' | egrep -v "$whitelist_re" || true)

if test "$opt_rubytoo"
then
    OLDGEMS=`dpkg-query -l | egrep rubygem- | grep -v integration | awk '{print $2}' || true`
fi
if test "$OLDPKGS"
then
    OLDPKGS="$OLDPKGS $OLDGEMS"
else
    OLDPKGS="$OLDGEMS"
fi

if test "$OLDPKGS"
then
    dpkg -r $OLDPKGS || true
    apt-get remove -y $OLDPKGS || true
fi

if test "$OLDPKGS"
then
    dpkg --purge $OLDPKGS || true
fi

if $undev
then
    devpkgs=$(dpkg-query -l '*-dev' | tail -n +7 | grep '^ii' | egrep -v "$whitelist_re" | egrep -v 'libc++-dev|libc6-dev|libgcc-.*-dev|libstdc.*-dev|dpkg-dev' | awk '{print $2}')
    apt-get remove -y $devpkgs
fi

if $opt_autoremove
then
    apt-get autoremove -y || true
fi

# Sanity check: make sure nothing in /opt/oblong
if dpkg-query -S /opt/oblong
then
    echo fail, dpkg says /opt/oblong is not empty
    exit 1
fi

if ls /opt/oblong 2>/dev/null
then
    echo warning, removing non-packaged files from /opt/oblong
    rm -rf /opt/oblong
fi

checkfiles() {
    if ls "$@" 2>/dev/null
    then
        echo FIXME: $@ was not removed.  See https://bugs.oblong.com/show_bug.cgi?id=7687
        rm -rf "$@"
    fi
}
checkfiles /etc/init.d/mz
checkfiles /etc/init.d/mz-pools-setup
checkfiles /etc/init.d/ob-http-ctl
checkfiles /etc/init.d/x11
checkfiles /etc/logrotate.d/ob-rotate-mezzanine
checkfiles /etc/oblong/quartermaster
checkfiles /etc/oblong/startup-commons
checkfiles /etc/oblong/xinitrc
checkfiles /etc/apt/sources.list.d/repobot-*oblong*.list

for dir in /var/ob /etc/oblong /mnt/poolsramdisk
do
    if ls $dir 2> /dev/null
    then
        if lsof $dir
        then
            echo WARNING: processes still using $dir
            echo Please kill them, then re-run
            exit 1
        fi
        echo warning, removing leftover files
        rm -rf $dir
    fi
done

if test "$opt_rubytoo"
then
    # Remove all gems, since having wrong versions of gems can cause problems for mezzanine
    if test -f /usr/bin/gem
    then
        case `ruby --version` in
        "ruby 1"*)
          gem list --no-versions |
            xargs --no-run-if-empty gem uninstall --executables --user-install --all
            ;;
        *)
          # ruby 2 added notion of default gems that cannot be uninstalled
          gem list --no-versions |
            grep -v -E "(bigdecimal|io-console|json|minitest|psych|rake|rdoc|test-unit)" |
            xargs --no-run-if-empty gem uninstall --executables --user-install --all --force
            ;;
        esac
    fi

    # Remove system gems next, since doing so may also uninstall gem iself
    SYSRUBYGEMS="`dpkg-query -S /usr/lib/ruby/vendor_ruby | sed 's/:.*//;s/,//g'`"
    if test "$SYSRUBYGEMS"
    then
        apt-get purge -y $SYSRUBYGEMS
    fi

    # Finally, totally uninstall all traces of ruby, since our packages should pull that in via dependencies as well.
    if $opt_autoremove
    then
        SYSRUBYPKGS="`dpkg-query -l | grep ruby | awk '{print $2}'`"
        if test "$SYSRUBYPKGS"
        then
            apt-get purge -y $SYSRUBYPKGS
        fi
    fi
fi

if ps augxw | grep oblong | grep -v grep
then
    echo "Some oblong processes may still be running.  You may need to kill them and/or reboot."
fi

# You may also need to remove and purge monit if we've screwed up its config file.
echo "Success, everything removed.  If not, please contact Oblong."
