#!/bin/sh
# Clean up large download artifacts (not in apt) older than one month
# Note: if disk fills up, you may have to delete zero-sized .pid files
# before buildbot will start up again.

# See also version-cleaner.sh, for those one-time cleanups of old versions.

set -x

RECIPIENTS="dank@oblong.com"
DIRS="/buildhost5_archive /home /"

date
df $DIRS

# Delete old versions.  We haven't been doing this, but it might save lots of space.
#timeout 120m ~/src/ob-repobot/arepo.sh flense

#--- 
# This does a full find on ~/.aptly, which takes AGES.
# Doing it in purge.sh save time because then it can share cache with
# the du.
# See also https://gitlab.oblong.com/platform/ob-repobot/issues/39
#timeout 120m ~/src/ob-repobot/arepo.sh cleanup

#--- Note disk usage ---
oldlogdir=`ls -trd ~/dulogs/* | tail -n 1`
datecode=`date +%F-%R`
newlogdir=$HOME/dulogs/$datecode
mkdir $newlogdir
sudo du --one-file-system $DIRS > $newlogdir/du.raw
sort -k +2 < $newlogdir/du.raw > $newlogdir/du.log
join -j 2 $oldlogdir/du.log $newlogdir/du.log | awk '$3 > $2 {print $3-$2, $1}' | sort -n -k +3 | sort -rn > $newlogdir/growth.log


#--- clean up artifact repositories ---
# First with a wide search and a lenient timeframe, then with a targeted search and a strict timeframe
# lenient = 30 days
# dev_lifetime = 14 days (and we should do a weekly build of those bits so they stay fresh)
# try_lifetime = 2 days
soft_lifetime=25
dev_lifetime=13
dev_lifetime_short=6
try_lifetime=4    # allow friday tries to live until end of monday

#--- purge trybuilders ---
find -L /var/repobot/*/builds/*-try-* -type f -mtime +$try_lifetime | xargs --no-run-if-empty rm -vf

#--- purge repobot/tarballs ---
find -L /var/repobot/tarballs -type f -ctime +$soft_lifetime | egrep '\.deb|\.dmg|\.pkg' | xargs  --no-run-if-empty rm -vf

known_offenders="
 oblong-*-gs3.*[13579]x
 mezzanine-*/*/*[13579]
 staging3.*[13579]
 staging-gh3.*[13579]
 oblong-platform/*/*[13579]
"
# This causes awful horrible problem: old packages being picked up as new
#(cd /var/repobot/tarballs; find -L $known_offenders -type f -ctime +$dev_lifetime -size +100k | xargs  --no-run-if-empty rm -vf)
df /var/repobot

#--- purge repobot/dev/builds ---
# First line purges all g-speak 3.19 build products; useful only very briefly after 3.21 development starts
#find /var/repobot/dev/builds -type f -ctime +$soft_lifetime | egrep 'gs3\.19|3\.19-3\.19' | xargs  --no-run-if-empty rm -rvf
find -L /var/repobot/dev/builds -type f -ctime +$soft_lifetime | egrep '\.deb|\.dmg|\.pkg' | xargs  --no-run-if-empty rm -vf
#find -L /var/repobot/dev/builds -type d -ctime +$soft_lifetime | egrep 'coverity.*output' | xargs  --no-run-if-empty rm -rvf
known_offenders="
 mezzanine-*
 growroom-*
 platform-*
"
(cd /var/repobot/dev/builds; find -L $known_offenders -type f -ctime +$dev_lifetime -size +100k | xargs  --no-run-if-empty rm -vf)
df /var/repobot

#--- purge repobot/dev/builds with shorter lifespan for builds with large artifacts ---
known_offenders="
 appup-generation-*
"
(cd /var/repobot/dev/builds; find -L $known_offenders -type f -ctime +$dev_lifetime_short -size +100k | xargs  --no-run-if-empty rm -vf)
df /var/repobot

#--- purge repobot/dev/builds with 2 days lifespan for builds whose artifacts aren't crucial ---
known_offenders="
 mezzanine-ubu1204gl-mz
 mezzanine-ubu1204gl-mz-coverage
 meow-*-longtests
"
(cd /var/repobot/dev/builds; find -L $known_offenders -type f -ctime +2 -size +10k | xargs  --no-run-if-empty rm -vf)
df /var/repobot
(cd /var/repobot/rel/builds; find -L $known_offenders -type f -ctime +2 -size +10k | xargs  --no-run-if-empty rm -vf)
df /var/repobot

#--- purge repobot/rel/builds ---
known_offenders="
 *-master3.*[13579]
 *-master3.*[13579]-gh
 *-master3.*[13579]-msvc*
"
(cd /home/buildbot/var/repobot/rel/builds; find -L $known_offenders -type f -ctime +7 -size +8k | xargs  --no-run-if-empty rm -vf)
df /var/repobot

known_offenders="
 mezzanine-ubu1204-rel-3.0-mz-chiltepe
 mezzanine-ubu1404-rel-3.0-mz-chiltepe
"
(cd /home/buildbot/var/repobot/rel/builds; find -L $known_offenders -type f -ctime +$soft_lifetime -size +8k | xargs  --no-run-if-empty rm -vf)
df /var/repobot

#--- purge package-monster ---
# big offender is platform-builder
# astor only needs 3.16 and 3.20, and only on ubu1204
ssh package-monster.oblong.com rm -rf /ob/dumper/g-speak/platform/ubu1[04]04 /ob/dumper/g-speak/platform/ubu1204/*gs3.1[02489]*gz

#--- purge obdumper ---
ssh git.oblong.com "df /ob/dumper; find /ob/dumper/g-speak/platform -name 'oblong-*-gs[3-9]\.*[13579]-*-*' -ctime +$dev_lifetime | xargs  --no-run-if-empty rm -vf; df /ob/dumper"

#--- report ---

> report.txt
report_queue()
{
    echo "$@" >> report.txt
}
report_by_os()
{
    (
    cd /var/repobot
    echo ===========================
    echo "Total usage on master by operating system:"
    echo -n ubu1004 " "; du *lucid*   */builds/*1004* -chs | tail -n 1
    echo -n ubu1204 " "; du *precise* */builds/*1204* -chs | tail -n 1
    echo -n ubu1404 " "; du *trusty*  */builds/*1404* -chs | tail -n 1
    echo -n ubu1510 " "; du *wily*    */builds/*1510* -chs | tail -n 1
    echo -n ubu1604 " "; du *xenial*  */builds/*1604* -chs | tail -n 1
    echo -n ubu1704 " "; du *zesty*   */builds/*1704* -chs | tail -n 1
    echo -n ubu1710 " "; du *artful*  */builds/*1710* -chs | tail -n 1
    echo -n osx107  " "; du tarballs/*/*osx107* */builds/*osx107* -chs | tail -n 1
    echo -n osx109  " "; du tarballs/*/*osx109* */builds/*osx109* -chs | tail -n 1
    echo -n osx1010 " "; du tarballs/*/*osx1010* */builds/*osx1010* -chs | tail -n 1
    echo -n osx1011 " "; du tarballs/*/*osx1011* */builds/*osx1011* -chs | tail -n 1
    echo -n osx1012 " "; du tarballs/*/*osx1012* */builds/*osx1012* -chs | tail -n 1

    )
}

report_send()
{
    if test -s report.txt
    then
        #report_by_os >> report.txt
        mail $RECIPIENTS -s "bot disk space warning" < report.txt
    fi
    rm report.txt
}

for slave in $(~/src/obs/buildbot/slaves.sh)
do
    used=`ssh buildbot@${slave} df \~buildbot/slave-state | grep / | grep '%' | sed 's/%.*//;s/.* //'`
    if test "$used" -gt 80
    then
        report_queue "WARNING: $slave disk space warning: $used% used"
    fi
    used=`ssh buildbot@${slave} df / | grep / | grep '%' | sed 's/%.*//;s/.* //'`
    if test "$used" -gt 80
    then
        report_queue "WARNING: $slave root disk space warning: $used% used"
    fi
done

for slave in git.oblong.com package-monster.oblong.com
do
    used=`ssh buildbot@${slave} df /ob/dumper | egrep / | grep '%' | sed 's/%.*//;s/.* //'`
    if test "$used" -gt 80
    then
        report_queue "WARNING: $slave disk space warning: $used% used"
    fi
done

# Local problems.  Has to be run on the buildhost.
problem=false
for dir in / /home /superfast_archive
do
    used=`df $dir | grep / | grep '%' | sed 's/%.*//;s/.* //'`
    if test "$used" -gt 75
    then
        report_queue "WARNING: `hostname` disk space warning: $dir is $used% used"
        problem=true
    fi
done
if $problem
then
    report_queue "$newlogdir/growth.log shows growth in these directories:"
    head -n 40 < $newlogdir/growth.log >> report.txt
fi

# Monitor for recurring vmware configuration snafu
# Assumes ob-version is installed everywhere, maybe we should put a
# special copy of it somewhere so it doesn't accidentally get uninstalled
for slave in $(~/src/obs/buildbot/slaves.sh) | grep -v win`
do
    cpu1=`ssh buildbot@${slave} grep -i model.name /proc/cpuinfo | uniq | sed 's/.*://'`
    cpu2=`ssh buildbot@${slave} ob-version | grep cpu.version | sed 's/.*://'`
    if test "$cpu1" != "$cpu2"
    then
        report_queue "$slave configuration warning: cpu names don't match ('$cpu1' != '$cpu2'), see bug 14946"
    fi
done

report_send

