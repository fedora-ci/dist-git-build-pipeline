#!groovy


def msg
def repoFullName
def repoName
def targetBranch
def prId
def prUid
def releaseId


pipeline {

    agent {
        label 'master'
    }

    triggers {
        ciBuildTrigger(
            noSquash: true,
            providerList: [
                rabbitMQSubscriber(
                    name: env.FEDORA_CI_MESSAGE_PROVIDER,
                    overrides: [
                        topic: 'org.fedoraproject.prod.pagure.pull-request.new',
                        queue: 'osci-pipelines-queue-5'
                    ],
                    checks: [
                        [field: '$.pullrequest.project.namespace', expectedValue: '^rpms$']
                    ]
                )
            ]
        )
    }

    parameters {
        string(name: 'CI_MESSAGE', defaultValue: '{}', description: 'CI Message')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    msg = readJSON text: CI_MESSAGE

                    repoFullName = msg['pullrequest']['project']['fullname']
                    repoName = msg['pullrequest']['project']['name']
                    targetBranch = msg['pullrequest']['branch']

                    prId = msg['pullrequest']['id']
                    prUid = msg['pullrequest']['uid']
                    prCommit = msg['pullrequest']['commit_stop']
                    prComment = 0

                    releaseId
                    if (targetBranch != 'master') {
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
                REPO_FULL_NAME = "${repoFullName}"
                REPO_NAME = "${repoName}"
                RELEASE_ID = "${releaseId}"
                PR_ID = "${prId}"
                PR_UID = "${prUid}"
                PR_COMMIT = "${prCommit}"
                PR_COMMENT = "${prComment}"
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
