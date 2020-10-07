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
                        [field: '$.pullrequest.namespace', expectedValue: '^rpms$']
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

                    repoFullName = msg['pullrequest']['fullname']
                    repoName = msg['pullrequest']['name']
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
                REPO_FULL_NAME = "${repoFullName}"
                REPO_NAME = "${repoName}"
                RELEASE_ID = "${targetBranch}"
                PR_ID = "${prId}"
                PR_UID = "${prUid}"
                PR_COMMIT = "${prCommit}"
                PR_COMMENT = "${prComment}"
	        }

            steps {
                container('koji') {
                    sh('pullRequest2scratchBuild.sh')
                }
            }
        }
    }
}
