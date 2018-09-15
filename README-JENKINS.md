# Jenkins Configuration

This app configures Jenkins to do CI / CD using a [Jenkinsfile](https://jenkins.io/doc/book/pipeline/jenkinsfile/).
The configuration does the following: 

* Build the app.
* Run the tests.
* Package the app as an AMI.
* If the commit is to `stage` or `prod`, automatically deploy the AMI to the corresponding environment.



## Setup instructions

To use these scripts in Jenkins, you will need to do the following:

1. [Install plugins](#install-plugins)
1. [Configure credentials](#configure-credentials)
1. [Create a build job in Jenkins](create-a-build-job-in-jenkins)


### Install plugins

When you first [install Jenkins](https://jenkins.io/download/), it walks you through a Setup Wizard. As part of that
process, we recommend using the standard set of plugins recommended by the Setup Wizard. On top of that, we also
typically install these plugins:

1. [SSH Agent Plugin](https://wiki.jenkins-ci.org/display/JENKINS/SSH+Agent+Plugin). This allows us to load SSH
   credentials into SSH Agent so that anything in your build that depends on SSH authentication (e.g. Terraform modules
   pulled down via SSH auth) will "just work".


### Configure credentials

Create a [GitHub Machine User](https://developer.github.com/guides/managing-deploy-keys/#machine-users) and configure
the user as follows:

1. Make sure your GitHub Machine User has read access to this repo.
1. GitHub OAuth Token. This token is also necessary to run Docker or Packer builds that use `gruntwork-install` so that
   the installer can access code in Gruntwork's private GitHub repos. [Create a token 
   here](https://github.com/settings/tokens) and make sure to enable `repo` and `admin_hooks` access.
1. SSH Keys. This is used so that Terraform modules can download code from private Git repos without having to specify
   the username and password directly in the Terraform code. [Create new SSH private/public keys as documented 
   here](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) and associate the 
   public key with the machine user's GitHub account [here](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/).

Next, head over to Jenkins and do the following: add these credentials to Jenkins using the  (which is one of the 
standard Jenkins plugins installed by default) to store them securely:

1. Add the GitHub OAuth Token as a "secret text" called `machine-user-github-oauth-token` using the [Credentials 
   Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Credentials+Plugin).
1. Add the private SSH key as a "secret SSH key" called `machine-user-github-ssh-keys` using the [Credentials 
   Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Credentials+Plugin).


### Create a build job in Jenkins

To configure Jenkins to use the `Jenkinsfile` in this repo: 

1. Create a new `Multibranch Pipeline` build job in Jenkins.
1. In the "Branch Sources" section:
    1. Add a Git source and specify the Git URL of this repo (e.g. `git@github.com:Veeps-Hosting/sample-app-frontend.git`). 
    1. For Credentials, select the `machine-user-github-ssh-keys` SSH keys you created earlier.
    1. Under "Behaviors", click the "Add" button, and select "Check out to matching local branch."
1. In the "Scan Multibranch Pipeline Triggers" section, check "Periodically if not otherwise run" and set it to 
   1 minute. To avoid exposing Jenkins to the outside world, we do NOT use webhooks, so you'll need to configure
   Jenkins to poll.
1. Leave all other settings at their defaults!