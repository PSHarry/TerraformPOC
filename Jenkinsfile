pipeline {
    agent any

    stages {
        stage('Build Environment'){
            steps {
                echo 'Building environment'
                sh 'terraform --version'
                sh 'terraform init'
                sh 'terraform plan'
                sh 'terraform apply --auto-approve'
            }
        }
        stage('Sleep for 10 minutes'){
            steps {
                echo 'Waiting for 10 minutes before cleanup'
                sleep(600)
            }
        }
        stage('Destroy environment') {
            steps {
                echo 'Destroying environment'
                sh 'terraform destroy --auto-approve'
            }
        }
    }
}
