#!/usr/bin/env groovy
def build_release;
def disagg_han_na;
def disagg_han_eu;
def disagg_gb;
def build_hybrid;
def disagg_py;
def PYTHON_BUILD;
def enigma_py;
def ENIGMA_BUILD;
def pdfval_py;
def dv;
def hb;
def hana;
def haeu;
def gbd;
def PDFVAL_BUILD;
pipeline {
    agent any


    parameters {
                string(name: 'DROP_VERSION' , defaultValue: "", description: 'Enter the Frontend Subdomian')

    }
    stages {
        stage('pingpong'){
            parallel {
                stage ("pyamidisagg"){
            steps{
                retry(3) {
                script {
                    disagg_py = build(
                    job: 'build-release-disagg-python',
                    )
                }
            }
           println 'Jenkins version:'
           script {
           PYTHON_BUILD = 'PROD_PYAMIDISAGG_1.0.'+disagg_py.displayName
           PYTHON_BUILD = PYTHON_BUILD.replace("#", "");
           println PYTHON_BUILD
            sh "echo $PYTHON_BUILD > pyi";
            sh "aws s3 cp pyi s3://bidgely-artifacts2"


           dv = DROP_VERSION
           sh   "echo $dv > DROP";
           sh "aws s3 cp DROP s3://bidgely-artifacts2"
           }

}
post {
                failure {
                    emailext attachLog: true, body: 'Pyami disagg failed', subject: 'PYAMI disagg failed', to: 'qa-india@bidgely.com'
                        error('Build has failed.')
                }
            }
}


    stage('build-py-engima'){
        steps{
            retry(3) {
            script {
                    enigma_py = build(
             job: 'build-release-eesavings-python',
             )
    }
}
        println 'PY Enigma version:'
        script {
        ENIGMA_BUILD='1.0.'+enigma_py.displayName
        ENIGMA_BUILD = ENIGMA_BUILD.replace("#", "");
        println ENIGMA_BUILD
        sh "echo $ENIGMA_BUILD > eni";
        sh "aws s3 cp eni s3://bidgely-artifacts2"
        }
}
post {
                failure {
                        emailext attachLog: true, body: 'Enigma failed', subject: 'enigma failed', to: 'qa-india@bidgely.com'
                        error('Build has failed.')
                }
            }
}

    stage('build-py-PDF-Validator'){
        steps{
            retry(3) {
            script {
                pdfval_py = build(
             job: 'build-release-pdfvalidator-python',
             )
            }
        }
            println 'PDF Validator Version:'
            script {
        PDFVAL_BUILD='1.0.'+pdfval_py.displayName
        PDFVAL_BUILD = PDFVAL_BUILD.replace("#", "");
        println PDFVAL_BUILD
        sh "echo $PDFVAL_BUILD > PDF";
            sh "aws s3 cp PDF s3://bidgely-artifacts2"
        }
    }
        post {
                failure {
                        emailext attachLog: true, body: 'PDF validator failed', subject: 'PDF validator failed', to: 'qa-india@bidgely.com'
                        error('Build has failed.')
                }
            }

        }
        stage ('build-release'){
            steps{
                retry(3) {
                script {
                    build_release = build(
                 job: 'build-release',
                 )
            }
        }
            println 'Build version:'
            script{
        println build_release.displayName
        bs = build_release.displayName
            sh   "echo $bs > result";
            sh "aws s3 cp result s3://bidgely-artifacts2"
            }

    }
        post {
                failure {
                                        emailext attachLog: true, body: 'Ping pong version failed', subject: 'ping pong failed', to: 'qa-india@bidg'
                                            error('Build has failed.')
                }
            }
        }

           stage('deploy hybrid'){


                    steps{
            retry(3) {
            script {
                        build_hybrid = build(
                        job: 'build-hybrid-models'
                        )
                    }
                }

        println 'Hybrid model version:'
        println build_hybrid.displayName
        script {
        hb = build_hybrid.displayName
        sh "echo $hb > hybrid"
        }
    }

    post {
                failure {
                                        emailext attachLog: true, body: 'Hybrid model failed', subject: 'Hybrid model failed', to: 'qa-india@bidgely.com'
                                        error('Build has failed.')
                }
            }

}
}
}
stage ('disagg'){
    parallel{
        stage ('build-han-na-disagg'){
            steps{
                retry(3) {
                script {
                  sh "aws s3 cp s3://bidgely-artifacts2/result ."
                    build_release=readFile('result').trim()
                println build_release
                        disagg_han_na = build(
                     job: 'build-release-disagg',
        parameters:[
                 [$class: 'StringParameterValue', name: 'GIT_BRANCH', value: 'master'],
                 [$class: 'StringParameterValue', name: 'JENKINSJOB', value: 'build-release'],
                 [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()]
                ]
                )
            }
        }
             println 'HAN-NA Disagg version:'
            println disagg_han_na.displayName
            script {
            hana = disagg_han_na.displayName
            sh   "echo $hana > hanadisagg";
            sh "aws s3 cp hanadisagg s3://bidgely-artifacts2"
        }
        }

        post {
                failure {
                                        emailext attachLog: true, body: 'HAN-NA failed', subject: 'HAN-NA failed', to: 'qa-india@bidgely.com'
                                        error('Build has failed.')
                }
            }


    }
    stage ('deploy-hybrid-models'){
            steps{
                script {
                    build_hybrid=readFile('hybrid').trim()
                build job: 'deploy-hybrid-models-nonprodqa',
                 parameters: [
                    [$class: 'StringParameterValue', name: 'MODELS_RELEASE_VERSION', value: build_hybrid.toString()],
                    [$class: 'StringParameterValue', name: 'TARGET_ENVIRONMENT', value: 'nonprodqa']
                ]
            }
            }

        }

    stage ('build-han-eu-disagg'){
        steps{
            retry(3) {
            script {
            build_release=readFile('result').trim()
                disagg_han_eu = build(
                job: 'build-release-disagg',
            parameters:[
                 [$class: 'StringParameterValue', name: 'GIT_BRANCH', value: 'release-han-eu'],
                 [$class: 'StringParameterValue', name: 'JENKINSJOB', value: 'build-release'],
                 [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()]
                ]
                )
            }
        }
        println 'HAN-EU Disagg version:'
        println disagg_han_eu.displayName
        script {
        haeu = disagg_han_eu.displayName
            sh   "echo $haeu > haeudisagg";
            sh "aws s3 cp haeudisagg s3://bidgely-artifacts2"
        }
        }

        post {
                failure {
                                        emailext attachLog: true, body: 'Pyami disagg failed', subject: 'HAN eu', to: 'qa-india@bidgely.com'
                                        error('Build has failed.')
                }
            }
    }


}
}
stage('deploy DB scripts'){
    parallel{
          stage ('deploy-rds'){
        steps{
            script {
                    build_release=readFile('result').trim()
                    println build_release
                    DROP_VERSION=readFile('DROP').trim()

            build job: 'deploy-api-db-nonprodqa',
             parameters:[
             [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
                [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
                [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
                [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
                [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
                [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'YES'],
                [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'NO']
                ]
            }
        }
    }
    stage ('deploy-redshift'){
        steps{
          script {
             build_release=readFile('result').trim()
                    println build_release
                    DROP_VERSION=readFile('DROP').trim()
            build job: 'deploy-api-db-nonprodqa',
             parameters:[
             [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
                [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
                [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
                [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
                [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
                [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'YES']
                ]
              }


        }
    }
    stage ('deploy-cassandra'){
        steps{
          script{
             build_release=readFile('result').trim()
                    println build_release
                    DROP_VERSION=readFile('DROP').trim()
            build job: 'deploy-api-db-nonprodqa',
             parameters:[
             [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
                [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
                [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
                [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
                [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
                [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'YES'],
                [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'NO']
                ]
              }
        }
    }
    stage('deploy-data-server'){
        steps{
          script{
             build_release=readFile('result').trim()
                    println build_release
                    DROP_VERSION=readFile('DROP').trim()
          sleep(45)
              build job: 'deploy-api-db-nonprodqa',
            parameters: [
                [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
                [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
                [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'YES'],
                [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
                [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
                [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'NO'],
                [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'NO']
            ]
          }
        }
    }

    }
}
stage('deploy global-configs'){
    steps{
      script{
          sleep(120)
          sh "aws s3 cp s3://bidgely-artifacts2/validate.sh ."
            sh "sh validate.sh"
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
          build job: 'deploy-api-db-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'global_configs', value: 'YES']

            ]
          }
        }
    }

stage('deploy data-server-scripts'){
    steps{
      script{
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
      sleep(45)
          build job: 'deploy-api-db-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'YES'],
            [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'NO']
            ]
          }
        }
    }

    stage('deploy launchpad-pilot-config'){
    steps{
      script{
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
          build job: 'deploy-api-db-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-server'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'YES'],
            [$class: 'StringParameterValue', name: 'RDS_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'CASSANDRA_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'REDSHIFT_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'LAUNCHPAD', value: 'YES']
            ]
          }
        }
    }
    stage('promote-static-files'){
    steps{
      script{
        sh "aws s3 cp  s3://bidgely-artifacts2/BUILD_NUMBER ."
         BUILD_NUMBER=readFile('BUILD_NUMBER').trim()
                println BUILD_NUMBER
        build job: 'promote-static-files-from-all',
        parameters: [
            [$class: 'StringParameterValue', name: 'BUILD_NUMBER', value: BUILD_NUMBER],
            [$class: 'StringParameterValue', name: 'BUILD_TYPE', value: 'release'],
            [$class: 'StringParameterValue', name: 'DISTINATION_BUCKET', value: 'nonprodqa']

            ]
          }
        }
    }




stage ('deploy-packages'){
        steps{
            script {
                sh "aws s3 cp  s3://bidgely-artifacts2/haeudisagg ."
                sh "aws s3 cp  s3://bidgely-artifacts2/hanadisagg ."
                sh "aws s3 cp s3://bidgely-artifacts2/pyi ."
                sh "aws s3 cp s3://bidgely-artifacts2/PDF ."
                sh "aws s3 cp s3://bidgely-artifacts2/eni ."



                build_release=readFile('result').trim()
                disagg_han_na=readFile('hanadisagg').trim()
                disagg_han_eu=readFile('haeudisagg').trim()
                PYTHON_BUILD=readFile('pyi').trim()
                ENIGMA_BUILD=readFile('eni').trim()
                PDFVAL_BUILD=readFile('PDF').trim()
                build_hybrid=readFile('hybrid').trim()

            build job: 'deploy-packages-nonprodqa',
             parameters: [
                [$class: 'StringParameterValue', name: 'JENKINSJOB', value: 'build-release'],
                [$class: 'StringParameterValue', name: 'ALL_DAEMONS', value: build_release.toString()],
                [$class: 'StringParameterValue', name: 'HAN_NA_DISAGG', value: disagg_han_na.toString()],
                [$class: 'StringParameterValue', name: 'HAN_EU_DISAGG', value: disagg_han_eu.toString()],
                [$class: 'StringParameterValue', name: 'PYAMIDISAGG', value:PYTHON_BUILD.toString()]
            ]
        }
    }

post {
                success {
emailext body: "Deployed Versions: \n Build : ${build_release.toString()} \n NA HAN Disagg : ${disagg_han_na.toString()} \n EU HAN Disagg : ${disagg_han_eu.toString()} \n GB Disagg : ${disagg_gb.toString()} \n Hybrid Disagg : ${build_hybrid.toString()} \n Python Disagg : ${PYTHON_BUILD.toString()} \n Python Enigma : ${ENIGMA_BUILD.toString()} \n Python PDF Validation : ${PDFVAL_BUILD.toString()}", subject: 'Deployment Completed!', to: 'qa-india@bidgely.com'


                }
}




}

stage('deploy launchpad'){
    steps{
      script{
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
          build job: 'deploy-api-db-launchpad-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'JENKINS_JOB_NUMBER', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'YES'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-launchpad'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO']

            ]
          }
        }
    }

    stage('deploy global-configs launchpad'){
    steps{
      script{
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
          build job: 'deploy-api-db-launchpad-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'JENKINS_JOB_NUMBER', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-launchpad'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'global_configs', value: 'YES']

            ]
          }
        }
    }


stage('deploy launchpad-api-scripts'){
    steps{
      script{
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
                      sleep(45)
        build job: 'deploy-api-db-launchpad-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'JENKINS_JOB_NUMBER', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-launchpad'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'YES']

            ]
          }
        }
    }

    stage('Velocity Update'){
    steps{
      script{
         build_release=readFile('result').trim()
                println build_release
                DROP_VERSION=readFile('DROP').trim()
                      sleep(45)
        build job: 'deploy-api-db-launchpad-nonprodqa',
        parameters: [
            [$class: 'StringParameterValue', name: 'JENKINS_JOB', value: 'build-release'],
            [$class: 'StringParameterValue', name: 'JENKINS_JOB_NUMBER', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'BUILD_VERSION', value: build_release.toString()],
            [$class: 'StringParameterValue', name: 'APISERVER_DEPLOYMENT', value: 'NO'],
            [$class: 'StringParameterValue', name: 'EBS_ENVIRONMENT', value: 'nonprodqa-api-launchpad'],
            [$class: 'StringParameterValue', name: 'DROP_VERSION', value: DROP_VERSION],
            [$class: 'StringParameterValue', name: 'API_SCRIPTS', value: 'NO'],
            [$class: 'StringParameterValue', name: 'VM_UPDATE', value: 'YES']


            ]
          }
        }
    }
//  stage ('test-smoke'){
//         steps{
//             build job: 'automation-qa-new1', propagate: false,
//             parameters: [
//                 [$class: 'StringParameterValue', name: 'Environment', value: 'newqa'],
//                 [$class: 'StringParameterValue', name: 'Platform', value: 'backend'],
//                 [$class: 'StringParameterValue', name: 'TestType', value: 'sanity']
//             ]
//         }
//     }
    }



}
