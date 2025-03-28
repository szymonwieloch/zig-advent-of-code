#!/bin/bash

set -eou pipefail

DONE=11

for i in $(seq 1 $DONE);
do
    echo Running challenge from day $i ========================
    zig test $i.zig
    zig run $i.zig
done
