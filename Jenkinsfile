pipeline {
  agent any

  environment {
    DOCKER_HUB_NAMESPACE = 'piyushinsys'
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
            sh 'docker logout || true'
            sh "docker build -t ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} ."
          } else {
            bat 'docker logout || exit 0'
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
              sh 'printf "%s" "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
              sh 'docker push ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}'
              sh '''
                if [ "${IS_MAIN}" = "true" ]; then
                  docker tag ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:latest
                  docker push ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:latest
                fi
              '''
            } else {
              bat 'powershell -Command "$env:DOCKER_PASS | docker login -u $env:DOCKER_USER --password-stdin"'
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

    stage('Deploy to Test (automated)') {
      steps {
        script {
          if (isUnix()) {
            sh '''
              set -e
              echo "Pulling image ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}"
              docker pull ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}

              # Stop previous container if exists (by name)
              if docker ps -a --format '{{.Names}}' | grep -q '^nodejs-sample-app$'; then
                echo "Stopping existing container nodejs-sample-app..."
                docker rm -f nodejs-sample-app || true
              fi

              # If port 5000 is in use by some other container, remove that container too
              OTHER=$(docker ps --filter "publish=5000" --format '{{.ID}}')
              if [ -n "$OTHER" ]; then
                echo "Found container using port 5000: $OTHER - removing it..."
                docker rm -f $OTHER || true
              fi

              echo "Starting container nodejs-sample-app (host:5000 -> container:5000)..."
              docker run -d --name nodejs-sample-app -p 5000:5000 ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}

              # Wait for health endpoint (max 30 sec)
              echo "Waiting for app health on http://localhost:5000/ ..."
              for i in $(seq 1 30); do
                if curl -sSf http://localhost:5000/ >/dev/null 2>&1; then
                  echo "App is healthy (responded)."
                  exit 0
                fi
                sleep 1
              done

              echo "Health check failed: app did not respond within 30 seconds."
              # Optionally fail the build (uncomment next line) or keep as warning
              exit 1
            '''
          } else {
            bat '''
              powershell -Command ^
                "docker pull ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG}; ^
                 if ((docker ps -a --format '{{.Names}}') -match '^nodejs-sample-app$') { docker rm -f nodejs-sample-app } ; ^
                 $other = (docker ps --filter 'publish=5000' --format '{{.ID}}'); if ($other) { docker rm -f $other } ; ^
                 docker run -d --name nodejs-sample-app -p 5000:5000 ${env.DOCKER_HUB_NAMESPACE}/${env.DOCKER_REPO}:${env.IMAGE_TAG} ; ^
                 Start-Sleep -s 1 ; ^
                 $ok = $false ; for ($i=0;$i -lt 30; $i++) { try { if ((Invoke-WebRequest -UseBasicParsing http://localhost:5000/).StatusCode -eq 200) { $ok = $true; break } } catch {} ; Start-Sleep -s 1 } ; if (-not $ok) { Write-Error 'Health check failed'; exit 1 }"
            '''
          }
        }
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
