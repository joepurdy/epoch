# Epoch - Ontra Infrastructure Engineer Homework <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [Video Overview](#video-overview)
- [Background](#background)
- [Installing / Getting started](#installing--getting-started)
  - [Initial Configuration](#initial-configuration)
- [Deploying the Infrastructure and Application](#deploying-the-infrastructure-and-application)
  - [Deploy the infrastructure](#deploy-the-infrastructure)
  - [Deploy the application](#deploy-the-application)
  - [Validate the application](#validate-the-application)
- [Architecture Overview](#architecture-overview)
  - [EKS](#eks)
  - [ECR](#ecr)
  - [Application Code](#application-code)
  - [Helm for Deployment](#helm-for-deployment)
- [Going further](#going-further)
  - [Multiple regions and replicas](#multiple-regions-and-replicas)
  - [Resource limits](#resource-limits)
  - [Readiness/Liveness probe improvements](#readinessliveness-probe-improvements)
  - [Refactoring the Helm chart](#refactoring-the-helm-chart)
  - [Terraform state](#terraform-state)
  - [Real CI/CD](#real-cicd)

## Video Overview

If you want to watch an XX minute video showing a demonstration of my homework solution I have one recorded here: [joepurdy/epoch — video overview](#TBD).

It's completely optional and merely provided to aid in reviewing the solution and seeing a practical demonstration.

## Background

I opted to stay within my lane so to speak and stick to Go, Terraform and Kubernetes (specifically EKS) to complete the takehome exercise. This let me make the most of the limited time and stay under a self-imposed timebox of 2 hours.

I've also used my standard local dev toolkit of asdf and direnv to manage all the various CLI tools needed to setup and manage the infrastructure. Reviewers that wish to provision my solution from this source are welcome to use asdf and direnv, or use their own preferences for installing local tools.

## Installing / Getting started

Bare minimum you'll need a working install of the following CLI tools:
- awscli
- kubectl
- helm
- eksctl
- terraform

As mentioned previously, I use asdf and direnv to manage all the various CLI tools needed so you can check [.tool-versions](.tool-versions) for specific tools and versions used.

If you [install asdf](https://asdf-vm.com/) you can run a provided setup script to take care of the boring bits.

```shell
./bin/setup
```

You'll also need to configure AWS credentials for whatever AWS account you want to provision infrastructure into. You'll also need a public domain to host the API at and an ACM certificate to use with the ALB Ingress. I cover these details more in the next section.

### Initial Configuration

As mentioned previously you'll need to configure AWS credentials, there's a number of ways to do this and I'll let you decide for yourself what works best. Since I was using a personal AWS account without SSO enabled I went with [aws-vault](https://github.com/99designs/aws-vault) (as seen in .tool-versions). I'm also a big fan of using [ax](https://github.com/ArcadiaPower/axolotl) which mimics the `aws-vault exec` command while supporting SSO enabled AWS accounts via Nike's gimme-aws-creds tool. _Humble brag: I wrote this tool_

You'll also need a public domain to host the API at and an ACM certificate to use with the ALB Ingress. If you're using direnv and ran the setup script you can update the `API_HOSTNAME` envionment variable in `.envrc` to be the public domain you wish to use.

_Note: Any changes to the `.envrc` file need to be followed by running `direnv allow` to pick up the changes._

With AWS credentials and that environment variable in place, either via direnv/`.envrc` or via your preferred manner of environment variable management, you can run the [bin/get-acm-cert](bin/get-acm-cert) script to request an ACM certificate. The script output will provide the DNS CNAME record you need to add to your DNS Zone to validate the certificate.

Once you have a certificate from ACM you should update the `ACM_CERTIFICATE_ARN` environment variable in `.envrc` with the certificate's ARN. This will be used in the ALB Ingress config.

## Deploying the Infrastructure and Application

1. [Deploy the infrastructure](#deploy-the-infrastructure)
2. [Deploy the application](#deploy-the-application)
3. [Validate the application](#validate-the-application)

### Deploy the infrastructure

Navigate to the [ops/terraform](ops/terraform) directory and run the following commands:

```shell
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

Be sure to inspect the plan output to confirm what you're deploying. The terraform managed infra covers the EKS cluster and the ECR repository primarily. There are also some anciliary resources that are created by terrafrom to support EKS like a VPC.

After the initial terraform managed resources are deployed you'll need to configure the EKS cluster with the AWS Load Balancer Controller to support public ingress.

To do this change to the [ops/helm/aws-lb](ops/helm/aws-lb) directory and run the [install-aws-lb-controller.sh](ops/helm/aws-lb/install-aws-lb-controller.sh) script:

```shell
./install-aws-lb-controller.sh
```

Once this is complete you have a working EKS cluster with the AWS Load Balancer Controller installed and you're ready to deploy the application.

### Deploy the application

From the root of the repository there are two scripts you can run to build and deploy the application. In a real-world situation deploying the application would be a concern for a CD pipeline, but for the sake of this exercise I scope this work to scripts that can be run locally. 

This is actually a practice I tend to use even when working with CD pipelines since having a working script for software delivery provides a "break glass" option for if hosted pipelines are unavailable and a change needs to be shipped urgently. This also avoids too much vendor lock-in with a CD provider and allows for flexibility when evaluating different solutions.

To build the application container and push to ECR:

```shell
./bin/build
```

Once you've built the container you can deploy it to EKS using the helm chart:

```shell
./bin/deploy
```

### Validate the application

Once the application is deployed you can access it at `https://` + `API_HOSTNAME` + `/`. The `NOTES.txt` for the Helm chart are configured to print this information to the terminal so you'll have an easy reference to get started.

If you access the endpoint from a browser you should see the current epoch time. You can also query it via cURL from your terminal like so:

```shell
curl -s https://`API_HOSTNAME`/
```

## Architecture Overview

The solution for this take-home exercise is architected to leverage Amazon Web Services (AWS) for hosting a Kubernetes-based application. The key components of the architecture include Amazon Elastic Kubernetes Service (EKS) for orchestration and Amazon Elastic Container Registry (ECR) for Docker image storage. Below is a detailed overview of each component and its role in the overall architecture.

### EKS

The core of the application infrastructure is an EKS cluster, which provides a managed Kubernetes service. This service simplifies the process of running Kubernetes on AWS without needing to install, operate, and maintain your own Kubernetes control plane or nodes. The specific aspects of EKS used in this solution include:

- **Cluster Setup**: The EKS cluster is provisioned with Terraform, ensuring an Infrastructure as Code (IaC) approach that is both repeatable and version-controlled.
- **Node Group**: The EKS cluster is configured with a node group to run the application pods. These nodes are AWS EC2 instances managed by EKS, providing the compute capacity for running the containerized application.
- **Load Balancing**: The architecture utilizes an AWS Application Load Balancer (ALB) to route external traffic to the application. The ALB is provisioned and managed automatically via the AWS Load Balancer Controller in the Kubernetes cluster, configured through Ingress resources.

### ECR

Amazon ECR is used as a container registry for storing the application's container images. ECR integrates seamlessly with EKS, providing a secure, scalable, and efficient registry for container image storage. Key features include:

- **Image Storage**: ECR hosts Docker images used by the Kubernetes deployment. Images are pushed to ECR via a CI/CD pipeline or manually via a script.
- **Image Scanning**: ECR performs automatic scans of images for vulnerabilities, improving the security posture of the application.

### Application Code

The application code is written in Go and provides a basic HTTP API endpoint. The application is containerized using multi-stage builds with the final runtime container being a `scratch` image that only contains the application binary.

### Helm for Deployment

Helm is used to manage the deployment of the application to the EKS cluster. Helm charts define the Kubernetes resources needed for deploying and operating the application, including Deployments, Services, and Ingress resources.

## Going further

As I completed the exercise I added some additional notes in the sections below describing some thoughts I had around ways to improve or expand on the solution given more time and context.

### Multiple regions and replicas

To save time (and money) the solution is built on a single EKS cluster in the us-west-2 region. If us-west-2 has a bad time or that EKS cluster is in a bad state the service fails.

It would be worthwhile in a production deployment to have multiple regions and multiple replicas. These tend to be trade-offs that need to be considered against the added cost of running a service in a highly available design.

Additionally, if running a multi-region service there needs to be some thought into how best to route requests between regions and if the default behavior is to serve from every region or keep a region as primary with other deployments scaled down/to zero as potential failover sites.

### Resource limits

The helm chart's values don't currently define any soft/hard resource limits (aka `resources.requests` and `resources.limits`). This is pretty easy to add and worth doing for anything you're putting into you k8s cluster to avoid greedy services.

### Readiness/Liveness probe improvements

As-is the readiness and liveness probes are as stock basic as they come. Which is actually fine in a way. The service for the exercise is also pretty basic with a single GET endpoint on the root path. So these probes are probably fine.

That said, I always prefer services with a `/health` endpoint dedicated to this sort of business. If nothing else it helps clean up your log output so you don't have to deal with log spam from the k8s scheduler probing the same endpoint your end users are hitting.

### Refactoring the Helm chart

The helm chart is based on what you get by running `helm create` which means there's a lot of unnecessary boilerplate. This was useful for getting a working solution in a minimal amount of time, however I'd absolutely spend more time refactoring this chart to be less "magic" and more declarative if this was a production service that was being maintained.

### Terraform state

There's no backend for managing remote terraform state. For a takehome exercise this is fine because the solution gets trashed very quickly. Any real infrastructure that a team depends on should have a remote state backend which can be as simple as an S3 bucket.

### Real CI/CD

There's no real CI/CD setup for this exercise. Instead I've written a `bin/build` and `bin/deploy` script which are both shell scripts that can be run locally or on CI/CD pipelines. There's no unit testing on the Go API either. There are areas that could and should be improved for a production service. Ideally, any change to terraform config would trigger an automatic `terraform plan` that posts to an open PR for the change. Also any merges to the trunk branch should automatically trigger a deployment that builds a new container image and deploys it via helm.
