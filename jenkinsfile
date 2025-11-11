pipeline {
  agent any

  environment {
    DOCKER_HUB_NAMESPACE = 'PiyushInsys'   
    DOCKER_REPO = 'node-js-sample'                   
    DOCKERHUB_CRED = 'dockerhub-practice-id'
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timestamps()
  }

  triggers {}  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          BRANCH = env.BRANCH_NAME ?: sh(returnStdout: true, script: "git rev-parse --abbrev-ref HEAD").trim()
          COMMIT = sh(returnStdout: true, script: "git rev-parse --short HEAD").trim()
          IMAGE_TAG = "${BRANCH}-${COMMIT}"
          IS_MAIN = (BRANCH == 'main' || BRANCH == 'master')
        }
      }
    }

    stage('Install & Test') {
      steps {
        sh 'npm ci'
        script {
          if (fileExists('package.json')) {
            def pkg = readJSON file: 'package.json'
            if (pkg.scripts?.test) {
              sh 'npm test'
            } else {
              echo "No test script found in package.json; skipping tests."
            }
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh """
           docker build -t ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG} .
        """
      }
    }

    stage('Login & Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED}", usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
          sh '''
            echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
            docker push ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}
          '''
          script {
            if (IS_MAIN) {
              
              sh """
                 docker tag ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:latest
                 docker push ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:latest
              """
            }
          }
        }
      }
    }

    stage('Prepare deployment metadata') {
      steps {
        sh """
          echo "image=${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}" > image.properties
          echo "branch=${BRANCH}" >> image.properties
          echo "commit=${COMMIT}" >> image.properties
        """
        archiveArtifacts artifacts: 'image.properties', fingerprint: true
      }
    }

    stage('Notify/Promote (optional)') {
      steps {
        echo "Image ready: ${DOCKER_HUB_NAMESPACE}/${DOCKER_REPO}:${IMAGE_TAG}"
      }
    }
  }

  post {
    success {
      echo "Pipeline succeeded."
    }
    failure {
      echo "Pipeline failed."
    }
    always {
      cleanWs()
    }
  }
}
