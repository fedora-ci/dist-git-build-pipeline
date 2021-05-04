#!/bin/bash

# Wait for scratch-build to finish.
#
# Return codes:
# 0 success
# 100 no build found for given package name
# 150 bad params

if [ $# -ne 1 ]; then
    echo "Usage: ${0} <task-id>"
    exit 150
fi

set -x

koji_bin="${KOJI_BIN:-/usr/bin/koji}"

task_id="${1}"
state="free"

while true
do
    "${koji_bin}" watch-task "${task_id}"
    # Are we really done? The state of the task should be "closed"
    state=$("${koji_bin}" taskinfo "${task_id}" | grep '^State: ' | awk -F' ' '{ print $2 }')
    if [ "${state}" == "free" ] || [ "${state}" == "open" ]; then
        # Nope, the task is still in progress -- let's continue watching it...
        continue
    fi
    # We are really done here!
    break
done

if [ "${state}" == "failed" ]; then
    exit 1
fi

exit 0
