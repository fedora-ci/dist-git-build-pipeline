#!/bin/bash

# Find "Source URL" (repo+hash) of the latest build for given package name
#
# Return codes:
# 0 success
# 100 no build found for given package name
# 150 bad params

if [ $# -ne 2 ]; then
    echo "Usage: ${0}  <package-name> <build-tag>"
    exit 150
fi

set -e
set -x

workdir="${PWD}"
source_url_file="${workdir}/source_url"
koji_bin="${KOJI_BIN:-/usr/bin/koji}"

package_name="${1}"
build_tag="${2}"

# Make sure we start with a clean workdir
rm -f ${source_url_file}

find_build() {
    # Find the latest build for given package name in given Koji tag.
    #
    # Params:
    # $1: package name
    # $2: Koji tag
    local name="${1}"
    local tag="${2}"

    latest_build=$("${koji_bin}" list-tagged --latest --inherit --quiet "${tag}" "${name}" | awk -F' ' '{ print $1 }')
    echo -n "${latest_build}"
}

get_source_url() {
    # Get the "Source URL" for given NVR.
    #
    # Params:
    # $1: NVR
    local nvr="${1}"

    local source_url=$("${koji_bin}" buildinfo "${nvr}" | grep '^Source: ' | awk -F' ' '{ print $2 }')
    echo -n "${source_url}"
}

nvr=$(find_build "${package_name}" "${build_tag}")
if [ -z "${nvr}" ]; then
    echo "No build found for given package name (${package_name}) in ${build_tag} Koji tag"
    exit 100
fi
source_url=$(get_source_url "${nvr}")
echo -n "${source_url}" | tee "${source_url_file}"
