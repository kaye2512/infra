pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        AWS_REGION     = 'eu-west-3'
        ECR_REPOSITORY = 'prod-ecr-repo'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.AWS_ACCOUNT_ID = sh(
                        script: 'aws sts get-caller-identity --query Account --output text',
                        returnStdout: true
                    ).trim()
                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE        = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"

                    // Dépôt IMMUTABLE : si ce tag existe déjà, l'image de ce commit est déjà dans ECR.
                    // describe-images renvoie 0 si le tag existe, une erreur sinon.
                    def exists = sh(
                        script: 'aws ecr describe-images --region "$AWS_REGION" --repository-name "$ECR_REPOSITORY" --image-ids imageTag="$IMAGE_TAG" > /dev/null 2>&1',
                        returnStatus: true
                    ) == 0
                    env.IMAGE_EXISTS = exists ? 'true' : 'false'
                }
                echo "Image : ${env.IMAGE} (déjà dans ECR : ${env.IMAGE_EXISTS})"
            }
        }

        stage('Build') {
            when { expression { env.IMAGE_EXISTS == 'false' } }
            steps {
                sh '''
                    docker build \
                      --build-arg APP_VERSION="$IMAGE_TAG" \
                      -t "$IMAGE" \
                      app/
                '''
            }
        }

        stage('Scan') {
            when { expression { env.IMAGE_EXISTS == 'false' } }
            steps {
                sh '''
                    # 1. Rapport complet HIGH + CRITICAL, pour information (ne bloque pas)
                    trivy image --no-progress --severity HIGH,CRITICAL --exit-code 0 "$IMAGE"

                    # 2. Barrière : échoue s'il reste une CRITICAL qui a un correctif
                    trivy image --no-progress --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
                '''
            }
        }

        stage('Push') {
            when { expression { env.IMAGE_EXISTS == 'false' } }
            steps {
                sh '''
                    # Jeton temporaire (12 h) obtenu avec le rôle IAM de l'instance : aucun mot de passe stocké
                    aws ecr get-login-password --region "$AWS_REGION" \
                      | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                    docker push "$IMAGE"
                '''
            }
        }
    }

    post {
        always {
            // Libère le disque du bastion et retire les identifiants Docker, même si le build a échoué
            sh '''
                if [ -n "$IMAGE" ]; then docker image rm "$IMAGE" || true; fi
                if [ -n "$ECR_REGISTRY" ]; then docker logout "$ECR_REGISTRY" || true; fi
                docker image prune -f
            '''
        }
        success {
            echo "Image disponible : ${env.IMAGE}"
        }
    }
}