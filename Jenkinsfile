library(
    identifier:'pipeline-lib@4.3.1',
    retriever:modernSCM([$class:'GitSCMSource',
    remote:'https://github.com/SmartColumbusOS/pipeline-lib',
    credentialsId:'jenkins-github-user'])
)

def image, imageName
def doStageIf = scos.&doStageIf
def doStageIfRelease = doStageIf.curry(scos.changeset.isRelease)
def doStageUnlessRelease = doStageIf.curry(!scos.changeset.isRelease)
def doStageIfPromoted = doStageIf.curry(scos.changeset.isMaster)


node('infrastructure') {
    ansiColor('xterm') {
        scos.doCheckoutStage()
        stage("Checkout submodules") {
            sshagent(credentials: ["GitHub"]) {
                sh("GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' git submodule update --init --recursive")
            }
        }

        def SERVICE_NAME="micro-service-watchinator"
        imageName = "scos/${SERVICE_NAME}"
        imageTag = "${env.GIT_COMMIT_HASH}"

        doStageUnlessRelease('Build') {

            image = docker.build("${imageName}:${imageTag}")
            println image.getClass()
        }

        doStageUnlessRelease('Deploy to Dev') {
            scos.withDockerRegistry {
                image.push()
                image.push('latest')
            }
            deployTo('dev', imageName, imageTag)
        }

        doStageIfPromoted('Deploy to Staging')  {
            def environment = 'staging'

            deployTo(environment, imageName, imageTag)

            scos.applyAndPushGitHubTag(environment)

            scos.withDockerRegistry {
                image.push(environment)
            }
        }

        doStageIfRelease('Deploy to Production') {
            def releaseTag = env.BRANCH_NAME
            def promotionTag = 'prod'

            deployTo('prod', imageName, imageTag)

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image = scos.pullImageFromDockerRegistry("scos/${SERVICE_NAME}", env.GIT_COMMIT_HASH)
                image.push(releaseTag)
                image.push(promotionTag)
            }
        }
    }
}


def deployTo(environment, imageName, tag) {
    def extraVars = [
        'image_repository': "${scos.ecrHostname}/${imageName}",
        'tag': tag
    ]

    def terraform = scos.terraform(environment)
    sh "terraform init && terraform workspace new ${environment}"
    terraform.plan(terraform.defaultVarFile, extraVars)
    terraform.apply()
}
