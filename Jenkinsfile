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
        GITOPS_FILE    = 'gitops/demo/deployment.yaml'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    // Commit créé par Jenkins lui-même ([skip ci]) : on ne refait rien, sinon boucle infinie
                    env.SKIP_CI = sh(script: 'git log -1 --pretty=%B | grep -qF "[skip ci]"', returnStatus: true) == 0 ? 'true' : 'false'
                    if (env.SKIP_CI == 'true') {
                        currentBuild.description = 'Commit [skip ci] : rien à faire'
                        currentBuild.result = 'NOT_BUILT'
                        return
                    }

                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.AWS_ACCOUNT_ID = sh(
                        script: 'aws sts get-caller-identity --query Account --output text',
                        returnStdout: true
                    ).trim()
                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE        = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"

                    def exists = sh(
                        script: 'aws ecr describe-images --region "$AWS_REGION" --repository-name "$ECR_REPOSITORY" --image-ids imageTag="$IMAGE_TAG" > /dev/null 2>&1',
                        returnStatus: true
                    ) == 0
                    env.IMAGE_EXISTS = exists ? 'true' : 'false'
                    echo "Image : ${env.IMAGE} (déjà dans ECR : ${env.IMAGE_EXISTS})"
                }
            }
        }

        stage('Build') {
            when { expression { env.SKIP_CI == 'false' && env.IMAGE_EXISTS == 'false' } }
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
            when { expression { env.SKIP_CI == 'false' && env.IMAGE_EXISTS == 'false' } }
            steps {
                sh '''
                    trivy image --no-progress --severity HIGH,CRITICAL --exit-code 0 "$IMAGE"
                    trivy image --no-progress --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
                '''
            }
        }

        stage('Push') {
            when { expression { env.SKIP_CI == 'false' && env.IMAGE_EXISTS == 'false' } }
            steps {
                sh '''
                    aws ecr get-login-password --region "$AWS_REGION" \
                      | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                    docker push "$IMAGE"
                '''
            }
        }

        // Tourne même si l'image existait déjà : il faut que Git pointe vers le bon tag
        stage('Update GitOps') {
            when { expression { env.SKIP_CI == 'false' } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-token',
                                                  usernameVariable: 'GIT_USER',
                                                  passwordVariable: 'GIT_TOKEN')]) {
                    // Guillemets simples : le shell lit le token, Jenkins le masque dans les logs
                    sh '''
                        set -e
                        BRANCH="${GIT_BRANCH#origin/}"      # "origin/feature/x" -> "feature/x"

                        git config user.name  "jenkins"
                        git config user.email "jenkins@bastion.local"

                        # Jenkins a récupéré un commit (HEAD détaché) : on se replace sur la branche
                        git checkout -B "$BRANCH" "origin/$BRANCH"

                        # "#" comme séparateur : l'image contient des "/"
                        sed -i "s#image: .*/${ECR_REPOSITORY}:.*#image: ${IMAGE}#" "$GITOPS_FILE"

                        if git diff --quiet -- "$GITOPS_FILE"; then
                            echo "Git pointe déjà vers ${IMAGE_TAG} : rien à commiter"
                            exit 0
                        fi

                        git add "$GITOPS_FILE"
                        git commit -m "deploy(demo): ${IMAGE_TAG} [skip ci]"

                        # https://github.com/<user>/<repo>.git -> <user>/<repo>.git
                        REPO_PATH=$(git config --get remote.origin.url | sed -E 's#^https://([^@]*@)?github.com/##')
                        REMOTE="https://${GIT_USER}:${GIT_TOKEN}@github.com/${REPO_PATH}"

                        # Si quelqu'un a poussé entre-temps, on se remet à jour avant de pousser
                        git pull --rebase "$REMOTE" "$BRANCH"
                        git push "$REMOTE" "HEAD:$BRANCH"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                if [ -n "$IMAGE" ]; then docker image rm "$IMAGE" || true; fi
                if [ -n "$ECR_REGISTRY" ]; then docker logout "$ECR_REGISTRY" || true; fi
                docker image prune -f
            '''
        }
        success {
            echo "Déployé via GitOps : ${env.IMAGE}"
        }
    }
}