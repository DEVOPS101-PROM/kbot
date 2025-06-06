#!/usr/bin/env groovy

def call(Map config = [:]) {
    // Default configuration
    def defaultConfig = [
        targetOS: 'linux',
        targetArch: 'amd64',
        containerRuntime: 'docker',
        registry: 'ghcr.io',
        imageName: 'devops101-prom/kbot',
        credentialsId: 'ghcr-credentials',
        helmChartDir: 'helm',
        helmReleaseName: 'kbot',
        helmNamespace: 'default',
        deployToK8s: false
    ]

    // Merge default config with provided config
    config = defaultConfig + config

    pipeline {
        agent any

        parameters {
            choice(
                name: 'TARGET_OS',
                choices: ['linux', 'darwin', 'windows'],
                description: 'Target operating system'
            )
            choice(
                name: 'TARGET_ARCH',
                choices: ['amd64', 'arm64'],
                description: 'Target architecture'
            )
            string(
                name: 'CONTAINER_RUNTIME',
                defaultValue: config.containerRuntime,
                description: 'Container runtime (docker or podman)'
            )
            booleanParam(
                name: 'DEPLOY_TO_K8S',
                defaultValue: config.deployToK8s,
                description: 'Deploy to Kubernetes cluster after build'
            )
        }

        environment {
            DOCKER_REGISTRY = config.registry
            DOCKER_IMAGE = config.imageName
            VERSION = "${env.BUILD_NUMBER}"
            DOCKER_CREDENTIALS_ID = config.credentialsId
            HELM_CHART_DIR = config.helmChartDir
            HELM_RELEASE_NAME = config.helmReleaseName
            HELM_NAMESPACE = config.helmNamespace
        }

        stages {
            stage('Checkout') {
                steps {
                    checkout scm
                }
            }

            stage('Login to GHCR') {
                steps {
                    withCredentials([usernamePassword(
                        credentialsId: "${env.DOCKER_CREDENTIALS_ID}",
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh """
                            echo ${DOCKER_PASSWORD} | ${params.CONTAINER_RUNTIME} login ${DOCKER_REGISTRY} -u ${DOCKER_USERNAME} --password-stdin
                        """
                    }
                }
            }

            stage('Build') {
                steps {
                    script {
                        // Set default values if not provided
                        def targetOS = params.TARGET_OS ?: config.targetOS
                        def targetArch = params.TARGET_ARCH ?: config.targetArch
                        def containerRuntime = params.CONTAINER_RUNTIME ?: config.containerRuntime

                        // Build the image using Makefile
                        sh """
                            make image \
                                CONTAINER_RUNTIME=${containerRuntime} \
                                CURR_OS=${targetOS} \
                                ARCH=${targetArch}
                        """
                    }
                }
            }

            stage('Push') {
                steps {
                    script {
                        def targetOS = params.TARGET_OS ?: config.targetOS
                        def targetArch = params.TARGET_ARCH ?: config.targetArch

                        // Push the image using Makefile
                        sh """
                            make push \
                                CONTAINER_RUNTIME=${params.CONTAINER_RUNTIME} \
                                CURR_OS=${targetOS} \
                                ARCH=${targetArch}
                        """
                    }
                }
            }

            stage('Update Helm Chart') {
                steps {
                    script {
                        def targetOS = params.TARGET_OS ?: config.targetOS
                        def targetArch = params.TARGET_ARCH ?: config.targetArch
                        def newTag = "${env.VERSION}-${targetOS}-${targetArch}"

                        // Update values.yaml with new image tag
                        sh """
                            sed -i "s/tag: \".*\"/tag: \"${newTag}\"/" ${env.HELM_CHART_DIR}/values.yaml
                            git config --global user.name 'Jenkins'
                            git config --global user.email 'jenkins@example.com'
                            git add ${env.HELM_CHART_DIR}/values.yaml
                            git commit -m "Update image tag to ${newTag}"
                            git push
                        """
                    }
                }
            }

            stage('Deploy to Kubernetes') {
                when {
                    expression { return params.DEPLOY_TO_K8S == true }
                }
                steps {
                    script {
                        def targetOS = params.TARGET_OS ?: config.targetOS
                        def targetArch = params.TARGET_ARCH ?: config.targetArch
                        def newTag = "${env.VERSION}-${targetOS}-${targetArch}"

                        // Deploy using Helm
                        sh """
                            helm upgrade --install ${env.HELM_RELEASE_NAME} ${env.HELM_CHART_DIR} \
                                --namespace ${env.HELM_NAMESPACE} \
                                --create-namespace \
                                --set image.repository=${env.DOCKER_REGISTRY}/${env.DOCKER_IMAGE} \
                                --set image.tag=${newTag}
                        """
                    }
                }
            }
        }

        post {
            always {
                // Logout from GHCR
                sh """
                    ${params.CONTAINER_RUNTIME} logout ${DOCKER_REGISTRY} || true
                """
                deleteDir()
            }
            success {
                echo 'Pipeline completed successfully!'
            }
            failure {
                echo 'Pipeline failed!'
            }
        }
    }
} 