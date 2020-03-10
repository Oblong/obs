#!/bin/sh
set -e
for slave in $(sh slaves.sh | grep -v 'win' | grep -v pi3)
do
    echo -n "=== $slave   "
    # Do whatever dangerous thing you wanted to do, e.g.
    #ssh -t buildbot@${slave} 'rm -rf slave-state/buildsystem*; hostname' &
    #ssh -t buildbot@${slave} 'ps augxw | grep -v grep | egrep "bau|make|ninja" || (hostname && uptime && sudo shutdown -r now)' || true
    sleep 1
done
wait
