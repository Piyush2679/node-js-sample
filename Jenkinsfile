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
          def branch = null
          if (env.BRANCH_NAME) {
            branch = env.BRANCH_NAME
          } else if (isUnix()) {
            branch = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD || true').trim()
          } else {
            def out = bat(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
            branch = out.readLines().findAll { it?.trim() }.last()
          }

          if (branch == 'HEAD' && env.GIT_BRANCH) {
            branch = env.GIT_BRANCH.replaceAll('origin/', '')
          }

          def commit = null
          if (isUnix()) {
            commit = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          } else {
            def out = bat(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
            commit = out.readLines().findAll { it?.trim() }.last()
          }

          def imageTag = "${branch}-${commit}"
          def isMain = (branch == 'main' || branch == 'master')

          env.BUILD_BRANCH = branch
          env.BUILD_COMMIT = commit
          env.IMAGE_TAG = imageTag
          env.IS_MAIN = isMain.toString()

          echo "Branch: ${env.BUILD_BRANCH}, Commit: ${env.BUILD_COMMIT}, Image tag: ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Install & Test') {
      steps {
        script {
          def npmExists = (sh(returnStatus: true, script: 'which npm >/dev/null 2>&1') == 0)
          if (!npmExists && !isUnix()) {
            npmExists = (bat(returnStatus: true, script: 'where npm >nul 2>nul') == 0)
          }

          if (npmExists) {
            echo "npm found on agent — running npm install"
            if (isUnix()) {
              sh 'npm install'
            } else {
              bat 'npm install'
            }
          } else {
            echo "npm not found on agent — running npm inside node:18-alpine container (requires docker)"
            if (isUnix()) {
              sh '''
                docker run --rm -v "$PWD":/app -w /app node:18-alpine sh -c "npm install || exit 0; if grep -q '\\"test\\"\\s*:' package.json; then npm test || true; fi"
              '''
            } else {
              bat 'docker run --rm -v "%cd%":/app -w /app node:18-alpine powershell -Command "npm install; if ((Get-Content package.json) -match \\"\\\\\\"test\\\\\\"\\s*:\\\\") { npm test }"'
            }
          }

          if (fileExists('package.json')) {
            def hasTest = false
            if (isUnix()) {
              hasTest = (sh(returnStatus: true, script: "grep -q '\"test\"\\s*:' package.json") == 0)
            } else {
              hasTest = (bat(returnStatus: true, script: 'findstr /R /C:"\"test\"[ ]*:" package.json') == 0)
            }
            if (hasTest) {
              echo 'Running npm test...'
              if (isUnix()) { sh 'npm test' } else { bat 'npm test' }
            } else {
              echo 'No test script found in package.json; skipping tests.'
            }
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          if (isUnix()) {
            sh "docker build -t ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} ."
          } else {
            bat "docker build -t ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} ."
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
              sh "docker push ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG}"
              if (env.IS_MAIN == 'true') {
                sh "docker tag ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:latest"
                sh "docker push ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:latest"
              }
            } else {
              bat "powershell -Command \"$env:DOCKER_PASS | docker login -u $env:DOCKER_USER --password-stdin\""
              bat "docker push ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG}"
              if (env.IS_MAIN == 'true') {
                bat "docker tag ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:latest"
                bat "docker push ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:latest"
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
            sh "echo \"image=${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG}\" > image.properties"
            sh "echo \"branch=${env.BUILD_BRANCH}\" >> image.properties"
            sh "echo \"commit=${env.BUILD_COMMIT}\" >> image.properties"
          } else {
            bat "echo image=${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} > image.properties"
            bat "echo branch=${env.BUILD_BRANCH} >> image.properties"
            bat "echo commit=${env.BUILD_COMMIT} >> image.properties"
          }
        }
        archiveArtifacts artifacts: 'image.properties', fingerprint: true
      }
    }
  }

  post {
    success {
      echo "Pipeline succeeded: ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG}"
    }
    failure {
      echo "Pipeline failed."
    }
    always {
      cleanWs()
    }
  }
}
