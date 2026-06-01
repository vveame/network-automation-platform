# GitHub Actions Self-Hosted Runner Bridge to Jenkins

## Objective

This project uses Jenkins as the main CI/CD automation server for validating the local network automation platform.
The GitHub repository is public so that the project supervisor and evaluators can access the source code easily.

However, Jenkins is not exposed directly to the Internet. Instead, the project uses a GitHub Actions self-hosted runner installed on the DevOps VM as a secure bridge between GitHub and Jenkins.

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
Jenkins API on 127.0.0.1:9090
        ↓
Jenkins pipeline execution
```

## Security Design

Because the repository is public, the self-hosted runner is not used to build, test, deploy, or checkout the project code.

The runner only executes one local command:

```bash
sudo /usr/local/sbin/trigger-jenkins-pfe
```

The real CI/CD logic is handled by Jenkins through the `Jenkinsfile`.

This design keeps Jenkins private inside the local lab while still allowing automatic execution after each push to the `main` branch.

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

The script triggers Jenkins locally through:

```text
http://10.200.0.10:8080
```

The script does not contain the Jenkins API token directly. Instead, Jenkins credentials are stored locally in:

```text
/root/.jenkins_netrc
```

This credentials file is owned by root.

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

The Jenkins pipeline performs the following actions:

1. Cleans the Jenkins workspace.
2. Checks out the repository.
3. Displays the execution environment.
4. Prepares Ansible output directories.
5. Validates the Ansible inventory.
6. Runs Ansible syntax checks.
7. Executes the Ansible validation gate.
8. Generates an HTML summary report.
9. Synchronizes reports to the dashboard output directory.
10. Archives validation outputs as Jenkins artifacts.
11. Updates the Jenkins build description with dashboard and report links.

## Final Result

This setup provides an enterprise-like CI/CD trigger architecture:

* GitHub remains public for academic visibility.
* Jenkins remains private inside the local lab.
* The runner runs under a limited Linux user.
* The runner does not build or deploy code.
* Jenkins API credentials remain local to the DevOps VM.
* Jenkins performs the complete validation pipeline.
