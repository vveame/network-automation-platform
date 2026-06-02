# GitHub Actions Self-Hosted Runner Bridge to Jenkins

## Objective

This project uses Jenkins as the main CI/CD automation server for the local network automation platform.

The GitHub repository is public so that the project supervisor and evaluators can access the source code easily. However, Jenkins is not exposed directly to the Internet. Instead, a GitHub Actions self-hosted runner is installed on the DevOps VM and acts as a controlled local bridge between GitHub and Jenkins.

This design allows GitHub push events to trigger Jenkins while keeping Jenkins private inside the local lab environment.

## Architecture

```text
GitHub public repository
        ↓ push to main
GitHub Actions workflow
        ↓
Self-hosted runner on DevOps VM
        ↓
Limited Linux user: gha-runner
        ↓
Protected local trigger script
        ↓
Jenkins API on the DevOps VM
        ↓
Jenkins pipeline execution
```

## Security Design

Because the repository is public, the self-hosted runner is not used to build, test, deploy, or checkout the repository code.

The runner only executes one local command:

```bash
sudo /usr/local/sbin/trigger-jenkins-pfe
```

The real CI/CD logic is handled by Jenkins through the `Jenkinsfile`.

This design prevents the public repository from directly controlling the DevOps VM. The repository can trigger Jenkins, but it cannot modify or replace the protected local trigger script.

## Dedicated Runner User

A dedicated Linux user named `gha-runner` was created for the GitHub Actions self-hosted runner.

```bash
sudo useradd -m -s /bin/bash gha-runner
sudo passwd -l gha-runner
sudo gpasswd -d gha-runner sudo 2>/dev/null || true
sudo gpasswd -d gha-runner docker 2>/dev/null || true
```

This user has limited privileges:

* It does not have password login.
* It is not a member of the `sudo` group.
* It is not a member of the `docker` group.
* It only has permission to run one controlled script through sudo.

## Runner Installation Path

The runner is installed in:

```text
/opt/actions-runner-pfe
```

The `/opt` directory is used because the GitHub Actions runner is a manually installed third-party application, not a normal project source file.

## Local Jenkins Trigger Script

The protected trigger script is installed on the DevOps VM at:

```text
/usr/local/sbin/trigger-jenkins-pfe
```

This location is used because the script is part of the local system administration configuration.

The script triggers Jenkins locally through the Jenkins API:

```text
http://10.200.0.10:8080
```

The script does not contain the Jenkins API token directly. Jenkins credentials are stored locally in:

```text
/root/.jenkins_netrc
```

This file is owned by `root` and must never be committed to GitHub.

## Parameterized Jenkins Trigger

The Jenkins job is parameterized. The local trigger script uses `buildWithParameters` and sends the default safe mode:

```text
PIPELINE_MODE=AUTO
CONFIRM_APPLY=false
AUTO_PUSH_IMAGES=true
DOCKERHUB_NAMESPACE=vviam
IMAGE_TAG=latest
PUBLISH_DASHBOARD=true
```

The `GNS3_HOST` value is kept in the protected local trigger script or provided manually in Jenkins. It is not hardcoded in the public repository.

## Sudoers Restriction

The `gha-runner` user is allowed to execute only the Jenkins trigger script:

```text
gha-runner ALL=(root) NOPASSWD: /usr/local/sbin/trigger-jenkins-pfe
```

This prevents the runner from having full administrative access to the DevOps VM.

## GitHub Actions Workflow

The workflow is stored in:

```text
.github/workflows/trigger-jenkins.yml
```

It is triggered only by:

* push events on the `main` branch
* manual execution using `workflow_dispatch`

The workflow does not use `actions/checkout`, because the runner should not download or execute repository code.

## Jenkins Pipeline Responsibility

Jenkins remains responsible for the real CI/CD pipeline.

The pipeline supports several execution modes:

```text
AUTO
VALIDATE_ONLY
BUILD_IMAGES
PUSH_IMAGES
BOOTSTRAP_GNS3
FULL_LOCAL_REFRESH
```

### AUTO Mode

`AUTO` is the default mode used by the GitHub Actions bridge.

In this mode, Jenkins:

1. Cleans the workspace.
2. Checks out the repository.
3. Detects changed repository areas.
4. Runs Ansible inventory and syntax validation.
5. Runs the local topology validation gate.
6. Generates an HTML summary report.
7. Publishes validation outputs to the Flask dashboard folder.
8. Archives validation outputs as Jenkins artifacts.

If Docker image files change, the pipeline can also build and publish the affected image. Docker build and push operations are delegated to the GNS3 host through SSH because Docker is installed on the GNS3 VM, not on the DevOps VM.

### Manual Maintenance Modes

Manual modes are launched from Jenkins using **Build with Parameters**.

* `BUILD_IMAGES`: builds all custom Docker images on the GNS3 host.
* `PUSH_IMAGES`: builds and pushes all custom Docker images to Docker Hub.
* `BOOTSTRAP_GNS3`: runs the persistent GNS3 bootstrap process.
* `FULL_LOCAL_REFRESH`: combines image refresh, bootstrap, and validation.

Topology-changing actions require:

```text
CONFIRM_APPLY=true
```

This confirmation is required for GNS3 bootstrap and full refresh operations because they modify the lab environment or persistent node configuration.

## Docker Image Lifecycle

The project uses custom Docker images for FRR routers, OVS switches, Web, and DNS service nodes.

Docker image build and push operations are executed on the GNS3 host because the GNS3 VM already contains the Docker environment required by the simulated topology.

Important distinction:

```text
docker build  → creates or updates a local image on the GNS3 host
docker push   → publishes the image to Docker Hub
GNS3 nodes    → existing containers are not automatically recreated
```

Pushing a new image to Docker Hub does not automatically update already-created GNS3 nodes. Applying a new image to existing GNS3 nodes requires a controlled maintenance action, such as recreating affected nodes or using a future GNS3 API-based refresh process.

## GNS3 Repository Sync

For Docker build and bootstrap operations, Jenkins connects to the GNS3 host through SSH and synchronizes the repository copy located at:

```text
/home/gns3/pfe-repo
```

The GitHub repository is treated as the source of truth for tracked files.

Real local environment and secret files are not stored in GitHub. They are preserved separately on the GNS3 host and restored after repository synchronization when needed.

Example local overlay path:

```text
/home/gns3/pfe-local-files
```

## Secrets and Sensitive Files

The following files must never be committed:

```text
/root/.jenkins_netrc
/opt/actions-runner-pfe/.credentials
/opt/actions-runner-pfe/.credentials_rsaparams
/opt/actions-runner-pfe/.runner
*.pem
*.key
*.env
```

The repository may contain `.example` files only.

Examples:

```text
secrets/ospf.env.example
ci-cd/jenkins-netrc.example
ci-cd/trigger-jenkins-pfe.example.sh
ci-cd/gha-runner-sudoers.example
```

## Final Result

This setup provides an enterprise-like CI/CD trigger architecture:

* GitHub remains public for academic visibility.
* Jenkins remains private inside the local lab.
* The GitHub Actions runner is limited to a local trigger role.
* The runner does not build, deploy, or checkout repository code.
* Jenkins API credentials remain local to the DevOps VM.
* Jenkins performs validation, reporting, and controlled maintenance workflows.
* Docker build and push operations are delegated to the GNS3 host.
* GNS3 topology-changing operations remain manual and protected by confirmation.