#!/bin/bash

# Scratch-build pull requests. And add enough metadata so it is later posible
# to map such scratch-builds back to pull requests.
#
# Note this is an ugly hack. The way the tracking works is by submitting a SRPM
# to Koji. The SRPM has a carefurly crafted name. The name is preserved by Koji
# and thus can be later "decoded" to get the information about the original
# pull request.
#
# SRPM naming schema:
# fedora-ci_<pr-uid>_<pr_commit_hash>_<pr_comment_id>;<fork-repo-full-name*>.f34.src.rpm
# Note "fork-repo-full-name" cannot contain URL unsafe characters, so all slashes
# are replaced with colons. I.e. "forks/user/rpms/repo" would be encoded as "forks:user:rpms:repo"
# in the SRPM name.

# Required environment variables:
# REPO_FULL_NAME - full name of the repository; for example: "rpms/jenkins"
# REPO_NAME - short name of the repository; for example: "jenkins"
# RELEASE_ID - release id; for example: "f34"
# PR_ID - pull request number; for example: 2
# PR_UID - Pagure's unique pull request id
# PR_COMMIT - commit hash
# PR_COMMENT - Pagure's comment id that triggered the testing, 0 if the pull request was just opened
# SOURCE_REPO_FULL_NAME - full name of the source repository; for example: "forks/user/rpms/repo"
# KOJI_KEYTAB - path to the keytab that can be used to build SRPMs in Koji
# KRB_PRINCIPAL - kerberos principal
# FEDPKG_OPTS - extra options to pass to the "fedpkg scratch-build" command

workdir=${PWD}
fedpkg_bin=${FEDPKG_BIN:-/usr/bin/fedpkg}
pagure_url=${PAGURE_URL:-https://src.fedoraproject.org}
mock_config="${RELEASE_ID}-x86_64"


# Guess the mock config name from the release id
epel_pattern="epel[0-9]+$"
epel_next_pattern="epel[0-9]+-next$"
if [[ "${RELEASE_ID}" == "${RAWHIDE_RELEASE_ID}" ]]; then
    # rawhide
    mock_config="fedora-rawhide-x86_64"
elif [[ "${RELEASE_ID}" == f* ]]; then
    mock_config="fedora-${RELEASE_ID:1}-x86_64"
elif [[ "${RELEASE_ID}" == epel7 ]]; then
    # just EPEL 7, there is no CentOS Stream 7
    mock_config="centos+epel-7-x86_64"
elif [[ "${RELEASE_ID}" =~ $epel_pattern ]]; then
    # EPEL 8+
    mock_config="centos-stream+epel-${RELEASE_ID:4}-x86_64"
elif [[ "${RELEASE_ID}" =~ $epel_next_pattern ]]; then
    # EPEL 8+ Next
    mock_config="centos-stream+epel-next-${RELEASE_ID:4:1}-x86_64"
fi

fedpkg_log_file="${workdir}/fedpkg.log"
koji_url_file="${workdir}/koji_url"
task_id_file="${workdir}/task_id"

set -e
set -x

rm -f "${fedpkg_log_file}"
rm -f "${koji_url_file}"
rm -f "${task_id_file}"

function cleanup() {
    # Remove directory, if it exists already
    local dir_name=${1}
    if [ -d "${dir_name}" ]; then
        rm -Rf ${dir_name}
    fi
}


function prepare_repository() {
    # Clone the repository and fetch the pull request changes
    local repo_full_name=${1}
    local pr_id=${2}
    local repo_name=$(basename ${repo_full_name})

    ${fedpkg_bin} clone -a ${repo_name}
    pushd ${repo_name}
        git fetch ${pagure_url}/${repo_full_name}.git refs/pull/${pr_id}/head:pr${pr_id}
        git checkout pr${pr_id}
    popd
}

cleanup ${REPO_NAME}
prepare_repository ${REPO_FULL_NAME} ${PR_ID}
cd ${REPO_NAME}

# Build SRPM
fedpkg sources
mock --isolation=simple --verbose -r "${mock_config}" --resultdir=./ --buildsrpm --spec *.spec --source .
srpm_path=$(ls -1 | grep ".src.rpm$" | awk '{ print $1 }')
srpm_name=$(basename ${srpm_path})
new_srpm_name="fedora-ci_${PR_UID}_${PR_COMMIT}_${PR_COMMENT};${SOURCE_REPO_FULL_NAME//\//:}.${RELEASE_ID}.src.rpm"
mv ${srpm_name} ${new_srpm_name}

# Scratch-build the SRPM in Koji
kinit -k -t ${KOJI_KEYTAB} ${KRB_PRINCIPAL}

${fedpkg_bin} scratch-build --nowait --fail-fast ${FEDPKG_OPTS} --target ${RELEASE_ID} --srpm ${new_srpm_name} | tee "${fedpkg_log_file}"

cat "${fedpkg_log_file}" | grep '^Task info: ' | awk '{ print $3 }' | tee "${koji_url_file}"

cat "${fedpkg_log_file}" | grep '^Created task: ' | awk '{ print $3 }' | tee "${task_id_file}"
