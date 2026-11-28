#!/bin/sh
# Runs mprisplayers.qml against two stand-in players called "Brave" on their own bus names.
# Not named tst_*.qml, so the main runner leaves it out. Run it inside dbus-run-session (ctest
# does), so the stand-ins never meet the real players. $1: the tst_qml runner.
here=$(dirname "$0")
python3 "$here/fakeplayer.py" fakeA Brave Song 10000000 2 & a=$!
python3 "$here/fakeplayer.py" fakeB Brave Song 100000000 1 & b=$!
"$1" -input "$here/mprisplayers.qml"
r=$?
kill $a $b
exit $r
