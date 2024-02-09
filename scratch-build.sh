#!/bin/bash

# Scratch-build pull requests in Koji.

# Required environment variables:
# KOJI_KEYTAB - path to the keytab that can be used to build packages in Koji
# KRB_PRINCIPAL - kerberos principal

workdir=${PWD}

if [ $# -ne 3 ]; then
    echo "Usage: $0 <koji-profile> <target> <scm-url>"
    exit 101
fi

koji_log=${workdir}/koji.log
koji_url=${workdir}/koji_url
task_id_file=${workdir}/task_id

set -e
set -x

rm -f ${koji_log}
rm -f ${koji_url}
rm -f ${task_id_file}

profile=${1}
target=${2}
source_url=${3}

if [ -z "${KOJI_KEYTAB}" ]; then
    echo "Missing keytab, cannot continue..."
    exit 101
fi

if [ -z "${KRB_PRINCIPAL}" ]; then
    echo "Missing kerberos principal, cannot continue..."
    exit 101
fi

kinit -k -t ${KOJI_KEYTAB} ${KRB_PRINCIPAL}

koji -p ${profile} build --scratch --fail-fast --nowait ${target} ${source_url} > ${koji_log}
cat ${koji_log}

cat ${koji_log} | grep '^Task info: ' | awk '{ print $3 }' > ${koji_url}

task_id=$(cat ${koji_log} | grep '^Created task: ' | awk '{ print $3 }' | tee ${task_id_file})
