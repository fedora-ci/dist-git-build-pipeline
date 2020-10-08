#!groovy

def releaseId


pipeline {

    agent {
        label 'master'
    }

    parameters {
        string(name: 'REPO_FULL_NAME', defaultValue: '', description: 'Full name of the repository; for example: "rpms/jenkins"')
        string(name: 'TARGET_BRANCH', defaultValue: 'master', description: 'Name of the target branch where the pull request should be merged')
        string(name: 'PR_ID', defaultValue: '1', description: 'Pull-Request Id (number)')
        string(name: 'PR_UID', defaultValue: '', description: "Pagure's unique internal pull-request Id")
        string(name: 'PR_COMMIT', defaultValue: '', description: 'Commit Id (hash) of the last commit in the pull-request')
        string(name: 'PR_COMMENT', defaultValue: '0', description: "Pagure's internal Id of the comment which triggered CI testing; 0 (zero) if the testing was triggered by simply opening the pull-request")
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    releaseId
                    if (TARGET_BRANCH != 'master') {
                        releaseId = "f${targetBranch}"
                    } else {
                        releaseId = env.FEDORA_CI_RAWHIDE_RELEASE_ID
                    }
                }
            }
        }

        stage('Scratch-Build in Koji') {
            agent {
                kubernetes {
                    label 'koji-agent'
                }
            }

            environment {
                KOJI_KEYTAB = credentials('fedora-keytab')
                KRB_PRINCIPAL = 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG'
                REPO_FULL_NAME = "${REPO_FULL_NAME}"
                REPO_NAME = "${REPO_FULL_NAME.split('/')[1]}"
                RELEASE_ID = "${releaseId}"
                PR_ID = "${PR_ID}"
                PR_UID = "${PR_UID}"
                PR_COMMIT = "${PR_COMMIT}"
                PR_COMMENT = "${PR_COMMENT}"
            }

            steps {
                container('koji') {
                    echo "REPO_FULL_NAME: ${REPO_FULL_NAME}"
                    echo "REPO_NAME: ${REPO_NAME}"
                    echo "RELEASE_ID: ${releaseId}"
                    echo "PR_ID: ${PR_ID}"
                    echo "PR_UID: ${PR_UID}"
                    echo "PR_COMMIT: ${PR_COMMIT}"
                    echo "PR_COMMENT: ${PR_COMMENT}"

                    sh('pullRequest2scratchBuild.sh')
                }
            }
        }
    }
}
