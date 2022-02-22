#!/bin/bash

# Wait for scratch-build to finish.
#
# Return codes:
# 0 success
# 1 failure
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
    # Are we done?
    # free/open/assigned means not done yet
    # closed/failed/cancelled means that the task is finished
    state=$("${koji_bin}" taskinfo "${task_id}" | grep '^State: ' | awk -F' ' '{ print $2 }')
    if [ "${state}" == "free" ] || [ "${state}" == "open" ] || [ "${state}" == "assigned" ]; then
        # Nope, the task is still in progress -- let's continue watching it...
        continue
    fi
    # We are really done here!
    break
done

# "closed" means success, everything else is a failure
if [ "${state}" != "closed" ]; then
    exit 1
fi

exit 0
