pipeline {
    agent any

    environment {
        AWS_REGION  = 'ap-southeast-2'
        AMI_ID_FILE = 'ami-id.properties'
        AMI_ID_KEY  = 'VERSION'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo 'Put your build/compilation steps here...'
            }
        }

        stage('Test') {
            steps {
                echo 'Put your automated tests steps here...'
            }
        }

        stage('Package') {
            steps {
                withCredentials([string(credentialsId: 'machine-user-github-oauth-token', variable: 'GITHUB_OAUTH_TOKEN')]) {
                    sh '''
                        build-packer-artifact --packer-template-path "packer/build.json" --build-name "sample-app-frontend" --output-properties-file "$AMI_ID_FILE"  --output-properties-file-key "$AMI_ID_KEY"
                    '''
                }
            }
        }

        stage('Deploy') {
             when {
                 anyOf {
                     branch 'stage'
                     branch 'prod'
                 }
             }
            steps {
                sshagent (credentials: ['machine-user-github-ssh-keys']) {
                    sh '''
                        
                        ami_id=$(cat "$AMI_ID_FILE" | sed s/"$AMI_ID_KEY"=//)
    
                        git config --global push.default simple
    
                        git clone git@github.com:Veeps-Hosting/infrastructure-live.git
    
                        cd "infrastructure-live/main/$AWS_REGION/$BRANCH_NAME/services/sample-app-frontend-asg"
                        terraform-update-variable --name "ami" --value "$ami_id" --git-user-email "grant+machine_github@veepshosting.com" --git-user-name "veepshosting-machine-user"
                        terragrunt apply --terragrunt-source-update -input=false -auto-approve
                    '''
                }
            }
        }
    }

    post {
        always {
            deleteDir() /* clean up our workspace */
        }
        success {
            echo 'Build succeeded!'
        }
        failure {
            echo 'Build failed!'
            /* mail to: 'team@example.com', subject: 'Build failed'*/
        }
    }
}