// The library version is controled from the Jenkins configuration
// To force a version add after lib '@' followed by the version.
@Library('msaas-shared-lib') _

node {
    // setup the global static configuration
    config = setupMsaasPipeline('msaas-config.yaml')

}


pipeline {

    agent {
        kubernetes {
            label "${config.pod_label}"
            yamlFile 'KubernetesPods.yaml'
        }
    }

    post {
        always {
            sendMetrics(config)
        }
    }

    stages {
        stage('BUILD:') {
            when {anyOf {branch '*'; branch 'master'; changeRequest()}}
            stages {
                stage('Podman Multi-Stage Build') {
                    steps {
                        container('podman') {
                            podmanBuild("--rm=false --build-arg=\"build=${env.BUILD_URL}\" -t ${config.image_full_name} .")
                            podmanMount(podmanFindImage([image: 'build', build: env.BUILD_URL]), {steps,mount ->
                                    sh(label: 'copy outputs to workspace', script: "cp -r ${mount}/usr/src/app/target ${env.WORKSPACE}")
                                })
                            podmanPush(config)
                        }
                    }
                }
                stage('Publish') {
                    parallel {
                        stage('Report Coverage & Unit Test Results') {
                            steps {
                                junit '**/surefire-reports/**/*.xml'
                                jacoco exclusionPattern: '**/com/intuit/expertnetwrk/onboarding/forms/model/**, **/com/intuit/expertnetwrk/onboarding/forms/authz/**,**/com/intuit/expertnetwrk/onboarding/forms/controller/rest/TasksController.*,**/com/intuit/expertnetwrk/onboarding/forms/graphql/**,**/com/intuit/expertnetwrk/onboarding/forms/repository/**,**/com/intuit/expertnetwrk/onboarding/forms/exception/**,**/com/intuit/expertnetwrk/onboarding/forms/Application.*,**/com/intuit/expertnetwrk/onboarding/forms/properties/*,**/com/intuit/expertnetwrk/onboarding/forms/constants/**,**/com/intuit/expertnetwrk/onboarding/forms/interceptor/LoggingInterceptor*,**/com/intuit/expertnetwrk/onboarding/forms/config/**,**/com/intuit/expertnetwrk/onboarding/forms/integration/Docusign/DocusignAPI.*,**/com/intuit/expertnetwrk/onboarding/forms/integration/salesforce/push_topic/listener/*,**/com/intuit/expertnetwrk/onboarding/forms/client/SalesforceOauthConfiguration*,**/com/intuit/expertnetwrk/onboarding/forms/integration/salesforce/push_topic/EmpConnectorFactory.*,**/com/intuit/expertnetwrk/onboarding/forms/client/IamTicketClientConfig*,**/com/intuit/expertnetwrk/onboarding/forms/controller/rest/SalesforceSyncContoller.*,**/com/intuit/expertnetwrk/onboarding/forms/controller/eventbus/events/**,**/com/intuit/expertnetwrk/onboarding/forms/controller/eventbus/producer/**,**/com/intuit/expertnetwrk/onboarding/forms/controller/eventbus/consumer/KafkaConsumerConfig.*,**/com/intuit/expertnetwrk/onboarding/forms/controller/logback/**,**${project.basedir}/lib/**,**/com/intuit/expertnetwrk/onboarding/forms/integration/salesforce/push_topic/factory/*,**/com/intuit/v4/expertnetwrk/onboarding/forms/generated/**'
                                codeCov(config)
                            }
                        }
                        stage('CPD Certification & Publish') {
                            steps {
                                container('cpd2') {
                                    intuitCPD2Podman(config, "-i ${config.image_full_name} --buildfile Dockerfile")
                                }
                                container('podman') {
                                    podmanPull(config, config.image_full_name)
                                    podmanInspect(config, '-s', 'image-metadata.json')
                                    archiveArtifacts(artifacts: 'image-metadata.json', allowEmptyArchive: true)
                                }
                            }
                        }
                        stage('Code Analysis') {
                            when {expression {return config.SonarQubeAnalysis}}
                            steps {
                                container('test') {
                                    echo 'Running static Code analysis: from JenkinsFile'
                                    reportSonarQube(config)
                                }
                            }
                        }
                        stage('Checkmarx') {
                            steps {
                                checkmarx(config)
                            }
                        }
                        stage('Nexus IQ Server Scan') {
                            steps {
                                nexusPolicyEvaluation failBuildOnNetworkError: false, iqApplication: "${config.asset_id}", iqStage: 'build'
                            }
                        }
                    }
                }
                stage('Send Build Metrics ODL') {
                    when {allOf {branch 'master'; not {changeRequest()}}}
                    steps {
                        sendBuildMetrics(config)
                    }
                }
                // jira transitioning
                stage('Transition Jira Tickets') {
                    steps {
                        script {
                            if (env.BRANCH_NAME != 'master' && changeRequest()) {
                                transitionJiraTickets(config, 'Ready for Review')
                            } else if (env.BRANCH_NAME == 'master') {
                                transitionJiraTickets(config, 'Closed')
                            }
                        }
                    }
                }
                stage('Scorecard Check') {
                    when {expression {return config.enableScorecardReadinessCheck}}
                    steps {
                        scorecardPreprodReadiness(config, 'qal-usw2')
                    }
                }
            }
        }
 stage('QAL:') {
        	parallel {
        		stage('qal-usw2-eks') {
		            when {allOf {branch 'master'; not {changeRequest()}}}
		            post {
                        always {
                            sendDeployMetrics(config, [boxsetVersion: "${config.image_full_name}", envName: 'qal-usw2-eks'])
                        }
                    }
		            options {
		                lock(resource: getEnv(config, 'qal-usw2-eks').namespace, inversePrecedence: true)
		                timeout(time: 32, unit: 'MINUTES')
		            }
		            stages {
		                stage('Deploy') {
		                    steps {
		                        container('cdtools') {
		                            //This has to be the first action in the first sub-stage.
		                            //milestone(ordinal: 20, label: 'Deploy-qal-usw2-eks-milestone')
		                            gitOpsDeploy(config, 'qal-usw2-eks', config.image_full_name)
		                        }
		                    }
		                }
		            }
		        }

		        stage('qal-use2-eks') {
		            when {allOf {branch 'master'; not {changeRequest()}}}
		            post {
                        always {
                            sendDeployMetrics(config, [boxsetVersion: "${config.image_full_name}", envName: 'qal-use2-eks'])
                        }
                    }
		            options {
		                lock(resource: getEnv(config, 'qal-use2-eks').namespace, inversePrecedence: true)
		                timeout(time: 32, unit: 'MINUTES')
		            }
		            stages {
		                stage('Deploy') {
		                    steps {
		                        container('cdtools') {
		                            // This has to be the first action in the first sub-stage
		                            //milestone(ordinal: 30, label: 'Deploy-qal-use2-eks-milestone')
		                            gitOpsDeploy(config, 'qal-use2-eks', config.image_full_name)
		                        }
		                    }
		                }
		            }
		        }
        	}
        }

        stage('E2E:') {
        	parallel {
        		stage('e2e-usw2-eks') {
		            when {anyOf {branch 'master'; branch 'develop'; not {changeRequest()}}}
		            post {
                        always {
                            sendDeployMetrics(config, [boxsetVersion: "${config.image_full_name}", envName: 'e2e-usw2-eks'])
                        }
                    }
		            options {
		                lock(resource: getEnv(config, 'e2e-usw2-eks').namespace, inversePrecedence: true)
		                timeout(time: 32, unit: 'MINUTES')
		            }
		            stages {
		//                  stage('Karate Functional & Performance Test') {
		//                      steps {
		//                          build job: 'expertnetwrk-onboarding/expertworkflows-automation'
		//                      }
		//                  }

		                stage('Scorecard Check') {
		                    when {expression {return config.enableScorecardReadinessCheck}}
		                    steps {
		                        scorecardPreprodReadiness(config, 'e2e-usw2-eks')
		                    }
		                }
		                stage('Deploy') {
		                    steps {
		                        container('cdtools') {
		                            //This has to be the first action in the first sub-stage.
		                           // milestone(ordinal: 40, label: 'Deploy-e2e-usw2-eks-milestone')
		                            gitOpsDeploy(config, 'e2e-usw2-eks', config.image_full_name)
		                        }
		                    }
		                }
		            }
		        }

		        stage('e2e-use2-eks') {
		            when {anyOf {branch 'master'; branch 'develop'; not {changeRequest()}}}
		            post {
                        always {
                            sendDeployMetrics(config, [boxsetVersion: "${config.image_full_name}", envName: 'e2e-use2-eks'])
                        }
                    }
		            options {
		                lock(resource: getEnv(config, 'e2e-use2-eks').namespace, inversePrecedence: true)
		                timeout(time: 32, unit: 'MINUTES')
		            }
		            stages {
		                stage('Scorecard Check') {
		                    when {expression {return config.enableScorecardReadinessCheck}}
		                    steps {
		                        scorecardPreprodReadiness(config, 'e2e-use2-eks')
		                    }
		                }
		                stage('Deploy') {
		                    steps {
		                        container('cdtools') {
		                            // This has to be the first action in the first sub-stage
		                            //milestone(ordinal: 50, label: 'Deploy-e2e-use2-eks-milestone')
		                            gitOpsDeploy(config, 'e2e-use2-eks', config.image_full_name)
		                        }
		                    }
		                }
		            }
		        }
        	}
        }


        stage('Transition Jira Tickets') {
            when {expression {return config.enableJiraTransition}}
            steps {
                transitionJiraTickets(config, 'Deployed to PreProd')
            }
        }

        /*stage('prf-usw2-eks') {
            when {
                beforeOptions true
                allOf {
                    branch 'develop'
                    not {changeRequest()}
                }
            }
            options {
                lock(resource: getEnv(config, 'prf-usw2-eks').namespace, inversePrecedence: true)
                timeout(time: 32, unit: 'MINUTES')
            }
            stages {
                stage('Scorecard Check') {
                    when {expression {return config.enableScorecardReadinessCheck}}
                    steps {
                        scorecardPreprodReadiness(config, 'prf-usw2-eks')
                    }
                }
                stage('Deploy') {
                    steps {
                        container('cdtools') {
                            // This has to be the first action in the first sub-stage
                            milestone(ordinal: 30, label: 'Deploy-prf-usw2-eks-milestone')
                            gitOpsDeploy(config, 'prf-usw2-eks', config.image_full_name)
                        }
                    }
                }
                stage('Transition Jira Tickets') {
                    when {expression {return config.enableJiraTransition}}
                    steps {
                        transitionJiraTickets(config, 'Deployed to PreProd')
                    }
                }
            }
        }

        stage('prf-use2-eks') {
            when {
                beforeOptions true
                allOf {
                    branch 'develop'
                    not {changeRequest()}
                }
            }
            options {
                lock(resource: getEnv(config, 'prf-use2-eks').namespace, inversePrecedence: true)
                timeout(time: 32, unit: 'MINUTES')
            }
            stages {
                stage('Scorecard Check') {
                    when {expression {return config.enableScorecardReadinessCheck}}
                    steps {
                        scorecardPreprodReadiness(config, 'prf-use2-eks')
                    }
                }
                stage('Deploy') {
                    steps {
                        container('cdtools') {
                            // This has to be the first action in the first sub-stage
                            milestone(ordinal: 50, label: 'Deploy-prf-use2-eks-milestone')
                            gitOpsDeploy(config, 'prf-use2-eks', config.image_full_name)
                        }
                    }
                }
                stage('Transition Jira Tickets') {
                    when {expression {return config.enableJiraTransition}}
                    steps {
                        transitionJiraTickets(config, 'Deployed to PreProd')
                    }
                }
            }
        }*/


        stage('Go Live in Prod Approval') {
            when {allOf {branch 'master'; not {changeRequest()}; not {expression {return config.preprodOnly}}}}
            agent none
            options {
                timeout(time: 1, unit: 'DAYS')
            }
            stages {
                stage('Prod Approval') {
                    steps {
                        gitOpsApproval(config, 'prd-usw2-eks')
                    }
                }
            }
        }
        stage('PROD primary') {
            when {
                beforeOptions true
                allOf {branch 'master'; not {changeRequest()}; not {expression {return config.preprodOnly}}}
            }
            options {
                lock(resource: getEnv(config, getEnvName(config, 'primary')).namespace, inversePrecedence: true)
                timeout(time: 22, unit: 'MINUTES')
            }
            stages {
                stage('Create CR') {
                    steps {
                        container('servicenow') {
                            sh label: 'Uncomment to open CR', script: 'exit 0'
                            openSnowCR(config, getEnvName(config, 'primary'), config.image_full_name)
                        }
                    }
                }
                stage('Deploy') {
                    steps {
                        container('cdtools') {
                            //This has to be the first action in the first sub-stage.
                            gitOpsDeploy(config, getEnvName(config, 'primary'), config.image_full_name)
                        }
                    }
                }
                // If any failure, CR remains open and MUST be closed manually with cause.
                stage('Close CR') {
                    steps {
                        container('servicenow') {
                            sh label: 'Uncomment to close CR', script: 'exit 0'
                            closeSnowCR(config, getEnvName(config, 'primary'))
                        }
                    }
                }
                // jira transitioning
                stage('Transition Jira Tickets') {
                    when {expression {return config.enableJiraTransition}}
                    steps {
                        transitionJiraTickets(config, 'Released')
                    }
                }
            }
        }
    }
}