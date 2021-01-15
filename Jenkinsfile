#!groovy

@Library('fedora-pipeline-library@34df5c8bb8ffa114b9dd7d704ebce4266211d779') _

def releaseId
def sourceRepo

def kojiUrl

def artifactId
def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'create an scratch build from PR',
    testCategory: 'static-analysis',
    testType: 'build',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/dist-git-build-pipeline',
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
    image: quay.io/fedoraci/pipeline-library-agent:251bda2
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

                    setBuildNameFromArtifactId(artifactId: artifactId)

                    sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                    if (TARGET_BRANCH != 'master') {
                        releaseId = params.TARGET_BRANCH
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
                REPO_FULL_NAME = "${params.REPO_FULL_NAME}"
                SOURCE_REPO_FULL_NAME = "${sourceRepo}"
                REPO_NAME = "${params.REPO_FULL_NAME.split('/')[1]}"
                RELEASE_ID = "${releaseId}"
                PR_ID = "${params.PR_ID}"
                PR_UID = "${params.PR_UID}"
                PR_COMMIT = "${params.PR_COMMIT}"
                PR_COMMENT = "${params.PR_COMMENT}"
            }

            steps {
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                script {
                    def rc = sh(returnStatus: true, script: 'pullRequest2scratchBuild.sh')
                    if (fileExists('koji_url')) {
                        kojiUrl = readFile("${env.WORKSPACE}/koji_url").trim()
                    }
                    catchError(buildResult: 'UNSTABLE') {
                        if (rc != 0) {
                            error('Failed to scratch build the pull request.')
                        }
                    }
                }
            }
        }
    }
    post {
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
    }
}
