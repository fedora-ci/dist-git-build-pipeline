#!groovy

retry (10) {
    // load pipeline configuration into the environment
    httpRequest("${FEDORA_CI_PIPELINES_CONFIG_URL}/environment").content.split('\n').each { l ->
        l = l.trim(); if (l && !l.startsWith('#')) { env["${l.split('=')[0].trim()}"] = "${l.split('=')[1].trim()}" }
    }
}

def artifactId
def packageName
def sidetagName
def taskId
def kojiUrl
def sourceUrl
def config

def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'Scratch-build packages in a side-tag',
    testCategory: 'validation',
    testType: 'scratch-build',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/dist-git-build-pipeline',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]

pipeline {

    agent {
        label 'scratch-build'
    }

    libraries {
        lib("fedora-pipeline-library@${env.PIPELINE_LIBRARY_VERSION}")
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: env.DEFAULT_DAYS_TO_KEEP_LOGS, artifactNumToKeepStr: env.DEFAULT_ARTIFACTS_TO_KEEP))
        timeout(time: env.DEFAULT_PIPELINE_TIMEOUT_MINUTES, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    parameters {
        string(name: 'ARTIFACT_ID', defaultValue: '', description: 'Artifact ID')
        string(name: 'PACKAGE_NAME', defaultValue: '', description: 'A name of the package to scratch-build')
        string(name: 'TEST_PROFILE', defaultValue: env.FEDORA_CI_RAWHIDE_RELEASE_ID, description: "A name of the test profile to use; Example: ${env.FEDORA_CI_RAWHIDE_RELEASE_ID}")
    }

    environment {
        KOJI_KEYTAB = credentials('fedora-keytab')
        KRB_PRINCIPAL = 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    artifactId = params.ARTIFACT_ID
                    if (!artifactId) {
                        abort('ARTIFACT_ID is missing -- bad input, cannot continue...')
                    }
                    setBuildNameFromArtifactId(artifactId: artifactId, profile: params.TEST_PROFILE)

                    packageName = params.PACKAGE_NAME
                    if (!artifactId) {
                        abort('PACKAGE_NAME is missing -- bad input, cannot continue...')
                    }

                    checkout scm
                    config = loadConfig(profile: params.TEST_PROFILE)

                    // Try to find the Source-URL (git url+hash) of the latest build of the given package
                    sh("./find-source-url.sh ${packageName} ${config.package_tag}")
                    if (fileExists('source_url')) {
                        sourceUrl = readFile("${env.WORKSPACE}/source_url").trim()
                    } else {
                        error("Unable to determine Source-URL for package ${packageName}")
                    }

                    sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: packageName, dryRun: isPullRequest())
                }
            }
        }

        stage('Prepare Side-Tag') {
            steps {
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: packageName, dryRun: isPullRequest())
                script {
                    // create a new side-tag and tag the given artifact into it
                    sh("./prepare-side-tag.sh ${getIdFromArtifactId(artifactId: artifactId)} ${config.base_tag}")
                    if (fileExists('sidetag_name')) {
                        sidetagName = readFile("${env.WORKSPACE}/sidetag_name").trim()
                    } else {
                        error('Failed to create a side-tag')
                    }
                }
            }
        }

        stage('Submit Scratch-Build') {
            steps {
                script {
                    // Submit a new scratch-build
                    sh("./submit-build.sh ${sourceUrl} ${sidetagName}")
                    if (fileExists('koji_url')) {
                        kojiUrl = readFile("${env.WORKSPACE}/koji_url").trim()
                    }
                    if (fileExists('task_id')) {
                        taskId = readFile("${env.WORKSPACE}/task_id").trim()
                    }
                    if (!kojiUrl || !taskId) {
                        error('Failed to submit a scratch-build')
                    }
                    // Send the "running" CI message second time -- this time with the Koji URL
                    sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, runUrl: kojiUrl, testScenario: packageName, dryRun: isPullRequest())
                }
            }
        }

        stage('Wait for Scratch-Build') {
            steps {
                script {
                    // Wait for the scratch-build to finish
                    def rc = sh(returnStatus: true, script: "./wait-build.sh ${taskId}")
                    catchError(buildResult: 'UNSTABLE') {
                        if (rc != 0) {
                            error("Scratch-build failed in Koji")
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (sidetagName) {
                    // Remove the side-tag
                    sh("./remove-side-tag.sh ${sidetagName}")
                }
            }
        }
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, runUrl: kojiUrl, testScenario: packageName, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, runUrl: kojiUrl, testScenario: packageName, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, runUrl: kojiUrl, testScenario: packageName, dryRun: isPullRequest())
        }
    }
}
