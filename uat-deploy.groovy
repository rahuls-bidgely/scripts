#!/usr/bin/env groovy

pipeline {
    agent any
    parameters {
                string(name: 'GIT_BRANCH' , defaultValue: "", description: 'Enter the Frontend Subdomian')
                string(name: 'ENV' , defaultValue: "", description: 'Enter the Frontend Subdomian')

              }

stages{
  stage('build-packages'){
    steps {
    build job: 'build-packages-dev-test',
    parameters: [
    [$class: 'StringParameterValue', name: 'GIT_BRANCH', value: GIT_BRANCH],
    [$class: 'StringParameterValue', name: 'ENV', value: ENV ]
    ]
  }
  }
  stage('deploy-packages'){
    when {
        expression { 
          ENV == 'ameren-autoscaling'
    }
    }
    steps{
      build job: 'deploy-packages-test',
      parameters: [
      [$class: 'StringParameterValue', name: 'InsatnceName', value: 'daemons-ameren-aggregations']

      ]

    }
    }

  }
}
