pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')   // pour tout le pipeline
        timestamps()
        disableConcurrentBuilds()            // un seul build à la fois
    }

    environment {
        AWS_REGION     = 'eu-west-3'
        ECR_REPOSITORY = 'prod-ecr-repo'     // le nom du dépôt créé par Terraform
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    // Tag = hash court du commit : relie l'image au code exact
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

                    // Compte AWS lu via le rôle IAM de l'instance : rien en dur dans le repo public
                    env.AWS_ACCOUNT_ID = sh(
                        script: 'aws sts get-caller-identity --query Account --output text',
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE        = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"
                }
                echo "Image à construire : ${env.IMAGE}"
            }
        }

        stage('Build') {
            steps {
                // Guillemets simples : c'est le shell qui lit les variables, pas Groovy
                sh '''
                    docker build \
                      --build-arg APP_VERSION="$IMAGE_TAG" \
                      -t "$IMAGE" \
                      app/
                    docker image ls "$ECR_REGISTRY/$ECR_REPOSITORY"
                '''
            }
        }
    }
}