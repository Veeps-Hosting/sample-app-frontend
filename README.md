# Sample-App-Frontend

This folder contains a sample app for demonstration and educational purposes. You should follow the example in this 
code in your own apps and then remove this sample app once things are working. The app is built on top of 
[Node.js](https://nodejs.org), but the basic approach works with any technology. 

This sample app shows how to:

1. Load the config file for the current environment.
1. Decrypt the secrets in the config file using [gruntkms](https://github.com/gruntwork-io/gruntkms).
1. Use Packer to package the app as an AMI. The AMI includes a script called `run-app.sh`. Terraform will configure
   each EC2 Instance to execute this script during boot (as part of User Data).
1. Make service calls to another app via a load balancer.




## Start here

If you're new to this infrastructure, Terraform, or AWS, make sure to start with the end-to-end 
[Infrastructure Walkthrough Documentation](https://github.com/Veeps-Hosting/infrastructure-live/tree/master/_docs). 




## Running the app in dev

```
cd app
npm install
node server.js
```




## Build the AMI

1. Install [Packer](https://www.packer.io/).

1. Configure your AWS credentials using one of the [options supported by the AWS 
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

1. `packer build packer/build.json`




## TLS certs

This app has self-signed TLS certificates in the `tls` folder. This is used to ensure that all data in transit is
encrypted. There is one private/public key pair for each environment (e.g. stage, prod, etc). 

If you are unfamiliar with how TLS certificates work, start with the [Background 
documentation](https://github.com/gruntwork-io/module-security/tree/master/modules/tls-cert-private#background).

There are many ways to generate a certificate, but the easiest option is:

1. Use the [private-tls-cert module](https://github.com/hashicorp/terraform-aws-vault/tree/master/modules/private-tls-cert)
   to generate the certificates. If you are using an ELB or ALB, then you can use any IP addresses or DNS names you 
   wish, as the AWS load balancers will not check. You may want to include `127.0.0.1` and `localhost` in the cert to 
   make local testing easier.
   
1. Encrypt the private key using [gruntkms](https://github.com/gruntwork-io/gruntkms) with the KMS master key for the
   appropriate environment.
   
1. Package the TLS cert with the app (the `Dockerfile` already does this).
   
1. Use `gruntkms` to decrypt the private key just before the app boots (the `run-app.sh` script already does this).




## Internal load balancer CA certs 

In order to talk to other apps in AWS, we make requests to an internal ALB over SSL. We have a copy of the CA cert for
the internal ALB in each environment under `tls/internal-alb-<ENV>-ca.pem`.