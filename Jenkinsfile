#!groovy

retry (10) {
    // load pipeline configuration into the environment
    httpRequest("${FEDORA_CI_PIPELINES_CONFIG_URL}/environment").content.split('\n').each { l ->
        l = l.trim(); if (l && !l.startsWith('#')) { env["${l.split('=')[0].trim()}"] = "${l.split('=')[1].trim()}" }
    }
}

def releaseId
def sourceRepo

def kojiUrl
def taskId

def artifactId
def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'Scratch-build Pull-Requests in Koji',
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
        timeout(time: '24', unit: 'HOURS')
    }

    parameters {
        string(name: 'REPO_FULL_NAME', defaultValue: '', description: 'Full name of the target repository; for example: "rpms/jenkins"')
        string(name: 'SOURCE_REPO_FULL_NAME', defaultValue: '', description: 'Full name of the source repository; for example: "fork/msrb/rpms/jenkins"')
        string(name: 'TARGET_BRANCH', defaultValue: 'rawhide', description: 'Name of the target branch where the pull request should be merged')
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
                    if (TARGET_BRANCH != 'rawhide') {
                        // fallback to rawhide in case this is not a standard fedora (or epel) branch
                        releaseId = (params.TARGET_BRANCH ==~ /f\d+|epel\d+/) ? params.TARGET_BRANCH : env.FEDORA_CI_RAWHIDE_RELEASE_ID
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
                RAWHIDE_RELEASE_ID = "${FEDORA_CI_RAWHIDE_RELEASE_ID}"
            }

            steps {
                script {
                    timeout(time: 240, unit: 'MINUTES') {
                        // lock buildroot
                        lock("${env.NODE_NAME}-mock-buildroot") {
                            def rc = sh(returnStatus: true, script: './pullRequest2scratchBuild.sh')
                            if (fileExists('koji_url')) {
                                kojiUrl = readFile("${env.WORKSPACE}/koji_url").trim()
                            }
                            if (fileExists('task_id')) {
                                taskId = readFile("${env.WORKSPACE}/task_id").trim()
                            }
                            if (!kojiUrl || !taskId) {
                                error('Failed to submit a scratch-build')
                            }
                        }
                    }
                    sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)

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
