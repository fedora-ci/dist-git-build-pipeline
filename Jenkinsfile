#!groovy

@Library('fedora-pipeline-library@e39c66874db516f9c33f052936d78b566b90be53') _

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
    image: quay.io/fedoraci/pipeline-library-agent:6063eae
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

        string(name: 'ARTIFACT_ID', defaultValue: '', description: 'Artifact ID')
        string(name: 'NVR', defaultValue: '', description: 'Artifact NVR')
        string(name: 'BUILD_TARGET', defaultValue: '', description: 'Name of the Koji build target')
        string(name: 'TEST_SCENARIO', defaultValue: '', description: "(optional) Name of the test scenario")
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    if (!params.REPO_FULL_NAME) {
                        currentBuild.result = 'ABORTED'
                        error('Bad input, nothing to do.')
                    }

                    if (params.PR_UID) {
                        // this is a pull request
                        artifactId = "fedora-dist-git:${params.PR_UID}@${params.PR_COMMIT}#${params.PR_COMMENT}"

                        setBuildNameFromArtifactId(artifactId: artifactId)

                        sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                        if (TARGET_BRANCH != 'master') {
                            // fallback to rawhide in case this is not a standard fedora branch
                            releaseId = (TARGET_BRANCH ==~ /f\d+/) ? params.TARGET_BRANCH : env.FEDORA_CI_RAWHIDE_RELEASE_ID
                        } else {
                            releaseId = env.FEDORA_CI_RAWHIDE_RELEASE_ID
                        }

                        sourceRepo = params.SOURCE_REPO_FULL_NAME
                        if (!sourceRepo) {
                            sourceRepo="${params.REPO_FULL_NAME}"
                        }
                    } else {
                        // this is a regular scratch-build request
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
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest())
                script {

                    def rc
                    if (params.PR_UID) {
                        // this is a pull request
                        rc = sh(returnStatus: true, script: 'pullRequest2scratchBuild.sh')
                    } else {
                        // this is a regular scratch-build request
                        def sidetagName
                        sh("build2sidetag.sh ${params.BUILD_TARGET} ${params.NVR}")
                        if (fileExists('sidetag_name')) {
                            sidetagName = readFile("${env.WORKSPACE}/sidetag_name").trim()
                        }
                        catchError(buildResult: 'UNSTABLE') {
                            if (!sidetagName) {
                                error("Failed to create side-tag for ${nvr}.")
                            }
                        }
                        rc = sh(returnStatus: true, script: "scratch.sh koji ${sidetagName} git+${FEDORA_CI_PAGURE_DIST_GIT_URL}/${params.REPO_FULL_NAME}#${params.TARGET_BRANCH}")
                    }
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
