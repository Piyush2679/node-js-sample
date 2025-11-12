pipeline {
  agent any

  environment {
    DOCKER_HUB_NAMESPACE = 'PiyushInsys'
    DOCKER_REPO          = 'node-js-sample'
    DOCKERHUB_CRED       = 'dockerhub-practice-id'
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timestamps()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          if (env.BRANCH_NAME) {
            BRANCH = env.BRANCH_NAME
          } else if (isUnix()) {
            BRANCH = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
          } else {
            BRANCH = bat(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
            BRANCH = BRANCH.readLines().findAll { it?.trim() }.last()
          }

          if (isUnix()) {
            COMMIT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          } else {
            COMMIT = bat(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
            COMMIT = COMMIT.readLines().findAll { it?.trim() }.last()
          }

          IMAGE_TAG = "${BRANCH}-${COMMIT}"
          IS_MAIN = (BRANCH == 'main' || BRANCH == 'master')
          echo "Branch: ${BRANCH}, Commit: ${COMMIT}, Image tag: ${IMAGE_TAG}"
        }
      }
    }

    stage('Install & Test') {
      steps {
        script {
          if (isUnix()) {
            sh 'npm ci'
          } else {
            bat 'npm ci'
          }

          if (fileExists('package.json')) {
            def hasTest = false
            if (isUnix()) {
              hasTest = (sh(returnStatus: true, script: "grep -q '\"test\"\\s*:' package.json") == 0)
            } else {
              // use findstr on Windows to look for "test" :
              hasTest = (bat(returnStatus: true, script: 'findstr /R /C:"\"test\"[ ]*:\" package.json') == 0)
            }

            if (hasTest) {
              echo 'Running npm test...'
              if (isUnix()) {
                sh 'npm test'
              } else {
                bat 'npm test'
              }
            } else {
              echo 'No test script found in package.json; skipping tests.'
            }
          } else {
            echo 'package.json not found; skipping tests.'
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          if (isUnix()) {
            sh "docker build -t ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${IMAGE_TAG} ."
          } else {
            bat "docker build -t %DOCKER_HUB_NAMESPACE%/%DOCKER_REPO%:${IMAGE_TAG} ."
          }
        }
      }
    }

    stage('Login & Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          script {
            if (isUnix()) {
              sh "echo \"$DOCKER_PASS\" | docker login -u \"$DOCKER_USER\" --password-stdin"
              sh "docker push ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${IMAGE_TAG}"
              if (IS_MAIN) {
                sh "docker tag ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${IMAGE_TAG} ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:latest"
                sh "docker push ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:latest"
              }
            } else {
              // Windows: use docker login with echo and pipe via powershell
              bat "powershell -Command \"$env:DOCKER_PASS | docker login -u $env:DOCKER_USER --password-stdin\""
              bat "docker push %DOCKER_HUB_NAMESPACE%/%DOCKER_REPO%:${IMAGE_TAG}"
              if (IS_MAIN) {
                bat "docker tag %DOCKER_HUB_NAMESPACE%/%DOCKER_REPO%:${IMAGE_TAG} %DOCKER_HUB_NAMESPACE%/%DOCKER_REPO%:latest"
                bat "docker push %DOCKER_HUB_NAMESPACE%/%DOCKER_REPO%:latest"
              }
            }
          }
        }
      }
    }

    stage('Prepare deployment metadata') {
      steps {
        script {
          if (isUnix()) {
            sh "echo \"image=${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}\" > image.properties"
            sh "echo \"branch=${BRANCH}\" >> image.properties"
            sh "echo \"commit=${COMMIT}\" >> image.properties"
          } else {
            bat "echo image=%DOCKER_HUB_NAMESPACE%/%DOCKER_REPO%:${IMAGE_TAG} > image.properties"
            bat "echo branch=%BRANCH% >> image.properties"
            bat "echo commit=%COMMIT% >> image.properties"
          }
        }
        archiveArtifacts artifacts: 'image.properties', fingerprint: true
      }
    }
  }

  post {
    success {
      echo "Pipeline succeeded: ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}"
    }
    failure {
      echo "Pipeline failed."
    }
    always {
      cleanWs()
    }
  }
}
