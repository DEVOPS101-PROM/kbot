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
        helmNamespace: 'default'
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
            choice(
                name: 'CONTAINER_RUNTIME',
                choices: ['docker', 'podman'],
                description: 'Container runtime'
            )
            string(
                name: 'HELM_NAMESPACE',
                defaultValue: config.helmNamespace,
                description: 'Kubernetes namespace for Helm deployment'
            )
        }

        environment {
            DOCKER_REGISTRY = config.registry
            DOCKER_IMAGE = config.imageName
            VERSION = "${env.BUILD_NUMBER}"
            DOCKER_CREDENTIALS_ID = config.credentialsId
            HELM_CHART_DIR = config.helmChartDir
            HELM_RELEASE_NAME = config.helmReleaseName
        }

        stages {
            stage('Checkout') {
                steps {
                    checkout scm
                }
            }

            stage('Setup Environment') {
                steps {
                    script {
                        // Set default values if not provided
                        env.TARGET_OS = params.TARGET_OS ?: config.targetOS
                        env.TARGET_ARCH = params.TARGET_ARCH ?: config.targetArch
                        env.CONTAINER_RUNTIME = params.CONTAINER_RUNTIME ?: config.containerRuntime
                        env.HELM_NAMESPACE = params.HELM_NAMESPACE ?: config.helmNamespace

                        // Print build configuration
                        echo """
                        Build Configuration:
                        - Target OS: ${env.TARGET_OS}
                        - Target Architecture: ${env.TARGET_ARCH}
                        - Container Runtime: ${env.CONTAINER_RUNTIME}
                        - Helm Namespace: ${env.HELM_NAMESPACE}
                        - Version: ${env.VERSION}
                        """
                    }
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
                            echo ${DOCKER_PASSWORD} | ${env.CONTAINER_RUNTIME} login ${env.DOCKER_REGISTRY} -u ${DOCKER_USERNAME} --password-stdin
                        """
                    }
                }
            }

            stage('Build') {
                steps {
                    script {
                        // Build the image using Makefile
                        sh """
                            make image \
                                CONTAINER_RUNTIME=${env.CONTAINER_RUNTIME} \
                                CURR_OS=${env.TARGET_OS} \
                                ARCH=${env.TARGET_ARCH}
                        """
                    }
                }
            }

            stage('Test') {
                steps {
                    script {
                        // Run tests
                        sh 'make test'
                    }
                }
            }

            stage('Push') {
                steps {
                    script {
                        // Push the image using Makefile
                        sh """
                            make push \
                                CONTAINER_RUNTIME=${env.CONTAINER_RUNTIME} \
                                CURR_OS=${env.TARGET_OS} \
                                ARCH=${env.TARGET_ARCH}
                        """
                    }
                }
            }

            stage('Update Helm Chart') {
                steps {
                    script {
                        def newTag = "${env.VERSION}-${env.TARGET_OS}-${env.TARGET_ARCH}"

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
                steps {
                    script {
                        // Deploy using Helm
                        sh """
                            helm upgrade --install ${env.HELM_RELEASE_NAME} ${env.HELM_CHART_DIR} \
                                --namespace ${env.HELM_NAMESPACE} \
                                --create-namespace \
                                --set image.repository=${env.DOCKER_REGISTRY}/${env.DOCKER_IMAGE} \
                                --set image.tag=${env.VERSION}-${env.TARGET_OS}-${env.TARGET_ARCH}
                        """
                    }
                }
            }

            stage('Verify Deployment') {
                steps {
                    script {
                        // Wait for deployment to be ready
                        sh """
                            kubectl rollout status deployment/${env.HELM_RELEASE_NAME} -n ${env.HELM_NAMESPACE} --timeout=300s
                        """
                    }
                }
            }
        }

        post {
            always {
                // Logout from GHCR
                sh """
                    ${env.CONTAINER_RUNTIME} logout ${env.DOCKER_REGISTRY} || true
                """
                cleanWs()
            }
            success {
                echo 'Pipeline completed successfully!'
                // Add success notifications here (e.g., Slack, email)
            }
            failure {
                echo 'Pipeline failed!'
                // Add failure notifications here
            }
            unstable {
                echo 'Pipeline is unstable!'
                // Add unstable notifications here
            }
        }
    }
} 