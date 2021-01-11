#!groovy

@Library('fedora-pipeline-library@candidate2') _

def releaseId
def sourceRepo

def artifactId
def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'Run tier-0 tests from dist-git',
    testCategory: 'functional',
    testType: 'tier0',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/dist-git-pipeline',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]

def podYAML = """
spec:
  containers:
  - name: koji-client
    # source: https://github.com/fedora-ci/jenkins-pipeline-library-agent-image
    image: quay.io/fedoraci/pipeline-library-agent:9daf458
    tty: true
    alwaysPullImage: true
"""


pipeline {

    agent {
        label 'dist-git-build'
    }

    parameters {
        string(name: 'REPO_FULL_NAME', defaultValue: '', description: 'Full name of the target repository; for example: "rpms/jenkins"')
        string(name: 'SOURCE_REPO_FULL_NAME', defaultValue: '', description: 'Full name of the source repository; for example: "fork/msrb/rpms/jenkins"')
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
                    if (!params.REPO_FULL_NAME) {
                        currentBuild.result = 'ABORTED'
                        error('Bad input, nothing to do.')
                    }

                    artifactId = "fedora-dist-git:${params.PR_UID}@${params.PR_COMMIT}#${params.PR_COMMENT}"
                    sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                    if (params.TARGET_BRANCH != 'master') {
                        releaseId = TARGET_BRANCH
                    } else {
                        releaseId = env.FEDORA_CI_RAWHIDE_RELEASE_ID
                    }

                    sourceRepo = params.SOURCE_REPO_FULL_NAME
                    if (!sourceRepo) {
                        sourceRepo="${params.REPO_FULL_NAME}"
                    }
                }
            }
        }

        stage('Scratch-Build in Koji') {
            agent {
                kubernetes {
                    yaml podYAML
                    defaultContainer 'koji-client'
                }
            }

            environment {
                KOJI_KEYTAB = credentials('fedora-keytab')
                KRB_PRINCIPAL = 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG'
                // ARCH_OVERRIDE = 'x86_64,i686'
            }

            steps {
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                sh("pr2scratch.sh koji wait ${releaseId} git+${env.FEDORA_CI_PAGURE_DIST_GIT_URL}/${params.SOURCE_REPO_FULL_NAME}.git#${params.PR_COMMIT}")
            }
        }
    }
    post {
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
    }
}
