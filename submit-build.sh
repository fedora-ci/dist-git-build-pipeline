#!/bin/bash

# Submit scratch-build.
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
    echo "Usage: ${0} <source-url> <side-tag>"
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

koji_log_file="${workdir}/koji.log"
koji_url_file="${workdir}/koji_url"
task_id_file="${workdir}/task_id"
koji_bin=${KOJI_BIN:-/usr/bin/koji}

source_url="${1}"
sidetag_name="${2}"

# Make sure we start with a clean workdir
rm -f "${koji_log_file}"
rm -f "${koji_url_file}"
rm -f "${task_id_file}"

kinit -k -t "${KOJI_KEYTAB}" "${KRB_PRINCIPAL}"

# submit new scratch-build, but do not wait for it to finish
"${koji_bin}" build --scratch --nowait --fail-fast "${sidetag_name}" "${source_url}" | tee "${koji_log_file}"

cat ${koji_log_file} | grep '^Task info: ' | awk '{ print $3 }' | tee "${koji_url_file}"
task_id=$(cat ${koji_log_file} | grep '^Created task: ' | awk '{ print $3 }')

echo -n "${task_id}" | tee "${task_id_file}"
