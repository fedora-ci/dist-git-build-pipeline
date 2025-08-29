#!groovy

retry (10) {
    // load pipeline configuration into the environment
    httpRequest("${FEDORA_CI_PIPELINES_CONFIG_URL}/environment").content.split('\n').each { l ->
        l = l.trim(); if (l && !l.startsWith('#')) { env["${l.split('=')[0].trim()}"] = "${l.split('=')[1].trim()}" }
    }
}

def buildTimeout = 600

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
        timeout(time: 24, unit: 'HOURS')
    }

    parameters {
        string(name: 'REPO_FULL_NAME', defaultValue: '', description: 'Full name of the target repository; for example: "rpms/jenkins"')
        string(name: 'SOURCE_REPO_FULL_NAME', defaultValue: '', description: 'Full name of the source repository; for example: "fork/msrb/rpms/jenkins"')
        string(name: 'TARGET_BRANCH', defaultValue: 'rawhide', description: 'Name of the target branch where the pull request should be merged')
        string(name: 'PR_ID', defaultValue: '1', description: 'Pull-Request Id (number)')
        string(name: 'PR_UID', defaultValue: '', description: "Pagure's unique internal pull-request Id")
        string(name: 'PR_COMMIT', defaultValue: '', description: 'Commit Id (hash) of the last commit in the pull-request')
        string(name: 'PR_COMMENT', defaultValue: '0', description: "Pagure's internal Id of the comment which triggered CI testing; 0 (zero) if the testing was triggered by simply opening the pull-request")
        booleanParam(name: 'IGNORE_TASK_ID_CACHE', defaultValue: false, description: "Ignore the previous commit's scratch-build cache")
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
                        releaseId = (params.TARGET_BRANCH ==~ /f\d+|eln|epel\d+|epel\d+\-next/) ? params.TARGET_BRANCH : env.FEDORA_CI_RAWHIDE_RELEASE_ID
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
                // TODO: What's the actual host?
                VALKEY_HOST = "localhost"
            }

            steps {
                script {
                    lock("check-concurrent-builds") {
                        def jobname = env.JOB_NAME
                        def output = sh(returnStdout: true, script: "python3 ./jenkins_build.py replace ${sourceRepo} ${params.PR_ID}").trim()
                        if (output != null && output != '') {
                            def job = Jenkins.instance.getItemByFullName(jobname)
                            job.getBuildByNumber(output).doStop()
                        }
                    }
                    timeout(time: buildTimeout, unit: 'MINUTES') {
                        // We don't really care if koji_find_task.py fails, the task_id/koji_url should be empty then
                        def rc = sh(returnStdout: true, script: "python3 ./koji_task.py find ${sourceRepo} ${params.PR_COMMIT}")
                        if (params.IGNORE_TASK_ID_CACHE || !fileExists('task_id')){
                            rc = sh(returnStatus: true, script: "./scratch-build.sh koji ${releaseId}-candidate git+https://src.fedoraproject.org/${sourceRepo}.git#${params.PR_COMMIT}")
                        }
                        if (fileExists('koji_url')) {
                            kojiUrl = readFile("${env.WORKSPACE}/koji_url").trim()
                        }
                        if (fileExists('task_id')) {
                            taskId = readFile("${env.WORKSPACE}/task_id").trim()
                        }
                        catchError(buildResult: 'UNSTABLE') {
                            if (rc != 0) {
                                error('Failed to scratch build the pull request.')
                            }
                        }
                        // Similarly with koji_find_task, we don't really care if this fails
                        rc = sh(returnStdout: true, script: "python3 ./koji_task.py save ${sourceRepo} ${params.PR_COMMIT}")
                        sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)

                        // Wait for the scratch-build to finish
                        rc = sh(returnStatus: true, script: "./wait-build.sh ${taskId}")
                        catchError(buildResult: 'UNSTABLE') {
                            if (rc != 0) {
                                error("Scratch-build failed in Koji")
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            lock("check-concurrent-builds") {
                sh(script: "python3 ./jenkins_build.py finish ${sourceRepo} ${params.PR_ID}")
            }
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)

            // Run dist-git tests on the scratch build, and report results back to the pull request
            build(
                wait: false,
                job: 'fedora-ci/dist-git-pipeline/master',
                parameters: [
                    string(name: 'ARTIFACT_ID', value: "(koji-build:${taskId})->${artifactId}"),
                    string(name: 'TEST_PROFILE', value: releaseId)
                ]
            )

            // Run the installability test on the scratch build, and report results back to the pull request
            build(
                wait: false,
                job: 'fedora-ci/installability-pipeline/master',
                parameters: [
                    string(name: 'ARTIFACT_ID', value: "(koji-build:${taskId})->${artifactId}"),
                    string(name: 'TEST_PROFILE', value: releaseId)
                ]
            )
        }
        aborted {
            script{
                // This can be either because it has timed-out or the job was canceled
                if (isTimeoutAborted(timeout: buildTimeout, unit: 'MINUTES')) {
                        // If it times-out than we should do nothing, but send a report to dist-git that it failed
                    sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)
                } else {
                        // Otherwise, it probably was canceled, so do not report anything, just cancel the koji build
                    sh(returnStatus: true, script: "koji cancel ${taskId}")
                }
            }
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest(), runUrl: kojiUrl)
        }
    }
}
