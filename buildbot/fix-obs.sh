#!/bin/sh
# Do obs-related configuration for all slaves.
set -e

# Do whatever it takes to get up to date obs on the remote machines.
# Note: developers use apt or brew packages on ubuntu and mac, but buildslaves just install obs from git.

for slave in `./slaves.sh | grep -v win | grep -v pi3`
do
    echo ===== $slave ====
    ssh -o StrictHostKeyChecking=no buildbot@${slave} "sh .obs/obs/buildbot/bootstrap-obs.sh" &
    sleep 1
done
wait

echo done
