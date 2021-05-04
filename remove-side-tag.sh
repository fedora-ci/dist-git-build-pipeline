#!/bin/bash

# Remove side-tag.
#
# Required environment variables:
# KOJI_KEYTAB - path to the keytab that can be used to build packages in Koji
# KRB_PRINCIPAL - kerberos principal
#
# Return codes:
# 0 success
# 150 bad params
# 160 bad configuration

workdir="${PWD}"

if [ $# -ne 1 ]; then
    echo "Usage: ${0} <side-tag>"
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

fedpkg_bin="${FEDPKG_BIN:-/usr/bin/fedpkg}"

sidetag_name="${1}"

kinit -k -t "${KOJI_KEYTAB}" "${KRB_PRINCIPAL}"

"${fedpkg_bin}" remove-side-tag "${sidetag_name}"
