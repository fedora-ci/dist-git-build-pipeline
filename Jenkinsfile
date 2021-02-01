#!groovy

@Library('fedora-pipeline-library@e39c66874db516f9c33f052936d78b566b90be53') _

def releaseId
def sourceRepo

def kojiUrl

def artifactId
def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'create an scratch build from PR',
    testCategory: 'validation',
    testType: 'scratch-build',
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
    image: quay.io/fedoraci/pipeline-library-agent:22a6960
    tty: true
    alwaysPullImage: true
"""


pipeline {

    agent {
        label 'dist-git-build'
    }

    parameters {
        string(name: 'REPO_FULL_NAME', defaultValue: '', description: 'Full name of the target repository; for example: "rpms/jenkins"')
        string(name: 'TARGET_BRANCH', defaultValue: 'master', description: 'Name of the target branch where the pull request should be merged')

        string(name: 'ARTIFACT_ID', defaultValue: '', description: 'Artifact ID')
        string(name: 'NVR', defaultValue: '', description: 'Artifact NVR')
        string(name: 'BUILD_TARGET', defaultValue: '', description: 'Name of the Koji build target')
        string(name: 'TEST_SCENARIO', defaultValue: '', description: "(optional) Name of the test scenario")
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    if (!params.ARTIFACT_ID) {
                        currentBuild.result = 'ABORTED'
                        error('Bad input, nothing to do.')
                    }
                    artifactId = "${params.ARTIFACT_ID}"
                    setBuildNameFromArtifactId(artifactId: artifactId)

                    sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest())
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
            }

            steps {
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest())
                script {


                    // create a new side-tag and tag the given artifact into it
                    def sidetagName
                    sh("build2sidetag.sh ${params.BUILD_TARGET} ${params.NVR}")
                    if (fileExists('sidetag_name')) {
                        sidetagName = readFile("${env.WORKSPACE}/sidetag_name").trim()
                    }

                    // scratch-build given REPO_URL+BRANCH in the side-tag
                    def rc
                    def repoAndRef = "git+${FEDORA_CI_PAGURE_DIST_GIT_URL}/${params.REPO_FULL_NAME}#${params.TARGET_BRANCH}"
                    if (sidetagName) {
                        rc = sh(returnStatus: true, script: "scratch.sh koji ${sidetagName} ${repoAndRef}")
                    } else {
                        catchError(buildResult: 'UNSTABLE') {
                            error("Failed to create side-tag for ${nvr}.")
                        }
                    }

                    if (fileExists('koji_url')) {
                        kojiUrl = readFile("${env.WORKSPACE}/koji_url").trim()
                    }
                    catchError(buildResult: 'UNSTABLE') {
                        if (rc != 0) {
                            error("Failed to scratch build ${repoAndRef}.")
                        }
                    }
                }
            }
        }
    }
    post {
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
    }
}
