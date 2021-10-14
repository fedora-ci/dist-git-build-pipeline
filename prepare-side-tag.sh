#!/bin/bash

# Create a side-tag and tag the given build(s) into it.
#
# Required environment variables:
# KOJI_KEYTAB - path to the keytab that can be used to build packages in Koji
# KRB_PRINCIPAL - kerberos principal
#
# Return codes:
# 0 success
# 100 no build found for given package name
# 150 bad params
# 160 bad configuration

workdir="${PWD}"

if [ $# -ne 2 ]; then
    echo "Usage: ${0} <task-ids> <base-tag>"
    exit 150
fi

if [ -z "${KOJI_KEYTAB}" ]; then
    echo "Missing keytab, cannot continue..."
    exit 160
fi

if [ -z "${KRB_PRINCIPAL}" ]; then
    echo "Missing kerberos principal, cannot continue..."
    exit 160
fi

set -e
set -x

request_log_file="${workdir}/sidetag_request.log"
sidetag_name_file="${workdir}/sidetag_name"
fedpkg_bin="${FEDPKG_BIN:-/usr/bin/fedpkg}"
koji_bin="${KOJI_BIN:-/usr/bin/koji}"

task_ids="${1}"
base_tag="${2}"

# Make sure we start with a clean workdir
rm -f "${request_log_file}"
rm -f "${sidetag_name_file}"

kinit -k -t "${KOJI_KEYTAB}" "${KRB_PRINCIPAL}"

# Create the side-tag
"${fedpkg_bin}" request-side-tag --base-tag "${base_tag}" | tee "${request_log_file}"

sidetag_name=$(cat "${request_log_file}" | grep ' created.$' | awk -F\' '{ print $2 }')

echo -n "${sidetag_name}" | tee "${sidetag_name_file}"

for task_id in ${task_ids}; do
    # Koji Task ID -> NVR
    nvr=$("${koji_bin}" taskinfo "${task_id}" |  grep '^Build: ' |  awk '-F ' '{ print $2 }')
    "${koji_bin}" tag "${sidetag_name}" "${nvr}"
done
