pipeline {
    agent any

    /*
     * Local Enterprise-Like Automation Pipeline
     *
     * Jenkins runs on the DevOps VM.
     * Docker image build/push is delegated to the GNS3 VM/host through SSH,
     * because Docker is installed on the GNS3 VM, not on the DevOps VM.
     *
     * Default AUTO mode is safe for GitHub push triggers.
     * GNS3 bootstrap actions require CONFIRM_APPLY.
     */

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 45, unit: 'MINUTES')
    }

    parameters {
        choice(
            name: 'PIPELINE_MODE',
            choices: [
                'AUTO',
                'VALIDATE_ONLY',
                'BUILD_IMAGES',
                'PUSH_IMAGES',
                'BOOTSTRAP_GNS3',
                'FULL_LOCAL_REFRESH'
            ],
            description: 'AUTO is used by GitHub push triggers. Manual modes are used from Jenkins UI.'
        )

        booleanParam(
            name: 'CONFIRM_APPLY',
            defaultValue: false,
            description: 'Required only for actions that modify the GNS3 host/topology state, such as BOOTSTRAP_GNS3 and FULL_LOCAL_REFRESH.'
        )

        booleanParam(
            name: 'AUTO_PUSH_IMAGES',
            defaultValue: true,
            description: 'In AUTO mode, push changed Docker images to Docker Hub after successful build.'
        )

        string(
            name: 'DOCKERHUB_NAMESPACE',
            defaultValue: 'vviam',
            description: 'Docker Hub namespace/user where images will be pushed. Change to vviam if that is your Docker Hub username.'
        )

        string(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'Docker image tag to build/push.'
        )

        string(
            name: 'GNS3_HOST',
            defaultValue: 'CHANGE_ME',
            description: 'IP address of the GNS3 VM/host reachable from the DevOps VM.'
        )

        booleanParam(
            name: 'PUBLISH_DASHBOARD',
            defaultValue: true,
            description: 'Copy latest reports to the Flask dashboard output folder.'
        )

        booleanParam(
            name: 'EXPORT_ARTIFACTS_TO_S3',
            defaultValue: false,
            description: 'Upload Ansible/Jenkins validation artifacts to the AWS S3 artifacts bucket after validation.'
        )

        string(
            name: 'S3_ARTIFACTS_BUCKET',
            defaultValue: 'CHANGE_ME',
            description: 'Terraform-created S3 artifacts bucket name. Keep CHANGE_ME in public repo and pass the real value from Jenkins or the local trigger script.'
        )

        string(
            name: 'CLOUD_AWS_REGION',
            defaultValue: 'eu-north-1',
            description: 'AWS region used for S3 artifact export.'
        )
    }

    environment {
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_HOST_KEY_CHECKING = 'False'

        DASHBOARD_OUTPUTS_DIR = '/var/lib/pfe-dashboard/outputs'
        DASHBOARD_URL = 'http://10.200.0.10:5050'

        FRR_IMAGE = 'pfe-frr-ssh'
        OVS_IMAGE = 'pfe-ovs-ssh'
        WEB_IMAGE = 'pfe-web-nginx'
        DNS_IMAGE = 'pfe-dns'
    }

    stages {
        stage('01 - Clean Jenkins Workspace') {
            /*
             * Purpose:
             * Start from a clean workspace so old files/reports do not affect the build.
             */
            steps {
                deleteDir()
            }
        }

        stage('02 - Checkout Repository') {
            /*
             * Purpose:
             * Pull the latest project code from GitHub into Jenkins.
             */
            steps {
                checkout scm
            }
        }

        stage('03 - Show Execution Environment') {
            /*
             * Purpose:
             * Print versions and runtime information for traceability/debugging.
             *
             * Docker is intentionally not required on the DevOps VM.
             * Docker build/push stages run remotely on the GNS3 host through SSH.
             */
            steps {
                sh '''
                    echo "Workspace: $WORKSPACE"
                    echo "User: $(whoami)"
                    echo "Host: $(hostname)"
                    echo "Pipeline mode: ${PIPELINE_MODE}"
                    echo "Docker namespace: ${DOCKERHUB_NAMESPACE}"
                    echo "Image tag: ${IMAGE_TAG}"

                    git --version
                    ansible --version
                    ansible-playbook --version

                    echo "[INFO] Local Jenkins does not need Docker. Docker work is delegated to the GNS3 host."
                '''
            }
        }

        stage('04 - Detect Changed Areas') {
            /*
             * Purpose:
             * Detect which parts of the repository changed in the latest commit.
             *
             * AUTO mode behavior:
             * - docker/frr-ssh changed   -> build/push FRR image only
             * - docker/ovs-ssh changed   -> build/push OVS image only
             * - docker/web-nginx changed -> build/push Web image only
             * - docker/dns changed       -> build/push DNS image only
             * - other changes            -> validation/reporting only
             */
            steps {
                sh '''
                    set -e

                    echo "[INFO] Detecting changed files..."

                    if git rev-parse HEAD~1 >/dev/null 2>&1; then
                        git diff --name-only HEAD~1 HEAD | tee changed-files.txt
                    else
                        echo "[WARN] First build or no previous commit. Marking all areas as changed."
                        git ls-files | tee changed-files.txt
                    fi

                    echo "[INFO] Changed files:"
                    cat changed-files.txt
                '''

                script {
                    def changedFiles = readFile('changed-files.txt')

                    env.CHANGED_DOCKER_FRR = changedFiles.contains('docker/frr-ssh/') ? 'true' : 'false'
                    env.CHANGED_DOCKER_OVS = changedFiles.contains('docker/ovs-ssh/') ? 'true' : 'false'
                    env.CHANGED_DOCKER_WEB = changedFiles.contains('docker/web-nginx/') ? 'true' : 'false'
                    env.CHANGED_DOCKER_DNS = changedFiles.contains('docker/dns/') ? 'true' : 'false'

                    env.CHANGED_DOCKER_ANY = (
                        env.CHANGED_DOCKER_FRR == 'true' ||
                        env.CHANGED_DOCKER_OVS == 'true' ||
                        env.CHANGED_DOCKER_WEB == 'true' ||
                        env.CHANGED_DOCKER_DNS == 'true'
                    ) ? 'true' : 'false'

                    env.CHANGED_GNS3 = changedFiles.contains('gns3/') ? 'true' : 'false'
                    env.CHANGED_ANSIBLE = changedFiles.contains('ansible/') ? 'true' : 'false'
                    env.CHANGED_DASHBOARD = changedFiles.contains('dashboard/') ? 'true' : 'false'
                    env.CHANGED_JENKINS = changedFiles.contains('Jenkinsfile') ? 'true' : 'false'

                    echo "CHANGED_DOCKER_FRR=${env.CHANGED_DOCKER_FRR}"
                    echo "CHANGED_DOCKER_OVS=${env.CHANGED_DOCKER_OVS}"
                    echo "CHANGED_DOCKER_WEB=${env.CHANGED_DOCKER_WEB}"
                    echo "CHANGED_DOCKER_DNS=${env.CHANGED_DOCKER_DNS}"
                    echo "CHANGED_DOCKER_ANY=${env.CHANGED_DOCKER_ANY}"
                    echo "CHANGED_GNS3=${env.CHANGED_GNS3}"
                    echo "CHANGED_ANSIBLE=${env.CHANGED_ANSIBLE}"
                    echo "CHANGED_DASHBOARD=${env.CHANGED_DASHBOARD}"
                    echo "CHANGED_JENKINS=${env.CHANGED_JENKINS}"
                }
            }
        }

        stage('05 - Safety Guard for GNS3 Apply Modes') {
            /*
             * Purpose:
             * Prevent accidental execution of topology-changing actions.
             *
             * BOOTSTRAP_GNS3 and FULL_LOCAL_REFRESH modify the GNS3 host
             * and persistent node configurations, so they require confirmation.
             */
            when {
                expression {
                    return params.PIPELINE_MODE in ['BOOTSTRAP_GNS3', 'FULL_LOCAL_REFRESH'] && !params.CONFIRM_APPLY
                }
            }
            steps {
                error('[SAFETY] CONFIRM_APPLY must be checked for BOOTSTRAP_GNS3 or FULL_LOCAL_REFRESH.')
            }
        }

        stage('06 - Safety Guard for GNS3 Host Requirement') {
            /*
             * Purpose:
             * Any Docker build/push or GNS3 bootstrap work now runs on the GNS3 host.
             * This stage fails early if the required GNS3_HOST parameter is not set.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'BOOTSTRAP_GNS3', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_ANY == 'true')
                    )
                }
            }
            steps {
                sh '''
                    set -e

                    if [ "$GNS3_HOST" = "CHANGE_ME" ] || [ -z "$GNS3_HOST" ]; then
                        echo "[ERROR] GNS3_HOST must be set for Docker build/push or GNS3 bootstrap stages."
                        echo "[INFO] Set GNS3_HOST in Jenkins Build with Parameters, or pass it from the local trigger script."
                        exit 1
                    fi
                '''
            }
        }

        stage('07 - Prepare Ansible Output Directory') {
            /*
             * Purpose:
             * Reset the Ansible outputs folder used for reports and dashboard files.
             */
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        rm -rf outputs
                        mkdir -p outputs
                    '''
                }
            }
        }

        stage('08 - Check GNS3 Host Access') {
            /*
             * Purpose:
             * Verify that Jenkins can reach the GNS3 VM/host through SSH.
             * Also confirms Docker works on the GNS3 host.
             *
             * This does not modify the topology.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'BOOTSTRAP_GNS3', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_ANY == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=no \
                            -o ConnectTimeout=10 \
                            "$GNS3_USER@$GNS3_HOST" \
                            "hostname && whoami && docker version && docker ps --format '{{.Names}}' | head"
                    '''
                }
            }
        }

        stage('09 - Sync Repo on GNS3 Host') {
            /*
            * Purpose:
            * Make sure the GNS3 host has the latest Dockerfiles, GNS3 scripts,
            * bootstrap scripts and configuration files.
            *
            * GitHub is the source of truth for tracked files.
            * Real local env/secret files are preserved separately in:
            * /home/gns3/pfe-local-files
            *
            * After force-syncing the repo, Jenkins restores those local files
            * back into /home/gns3/pfe-repo.
            */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_ANY == 'true') ||
                        (params.PIPELINE_MODE == 'BOOTSTRAP_GNS3' && params.CONFIRM_APPLY)
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" \
                        -o BatchMode=yes \
                        -o StrictHostKeyChecking=no \
                        -o ConnectTimeout=10 \
                        "$GNS3_USER@$GNS3_HOST" '
                            set -e

                            REPO_DIR="/home/gns3/pfe-repo"
                            REPO_URL="https://github.com/vveame/network-automation-platform.git"
                            LOCAL_FILES_DIR="/home/gns3/pfe-local-files"

                            mkdir -p "$LOCAL_FILES_DIR"

                            echo "[INFO] Preserving local env/secret files before repo sync..."
                            if [ -d "$REPO_DIR" ]; then
                                cd "$REPO_DIR"
                                find . -type f \\( -name "*.env" -o -name ".env" -o -name "*.secret" \\) \
                                -exec cp --parents {} "$LOCAL_FILES_DIR" \\; || true
                            fi

                            if [ ! -d "$REPO_DIR/.git" ]; then
                                echo "[WARN] $REPO_DIR is not a valid git repo."

                                if [ -d "$REPO_DIR" ]; then
                                    BACKUP_DIR="${REPO_DIR}.backup.$(date +%Y%m%d%H%M%S)"
                                    echo "[INFO] Moving existing folder to $BACKUP_DIR"
                                    mv "$REPO_DIR" "$BACKUP_DIR"
                                fi

                                echo "[INFO] Cloning repository..."
                                git clone "$REPO_URL" "$REPO_DIR"
                            fi

                            cd "$REPO_DIR"

                            echo "[INFO] Setting Git origin..."
                            git remote remove origin 2>/dev/null || true
                            git remote add origin "$REPO_URL"

                            echo "[INFO] Fetching latest main..."
                            git fetch --prune origin main

                            echo "[INFO] Forcing GNS3 working copy to match origin/main..."
                            git checkout -f -B main origin/main
                            git reset --hard origin/main
                            git clean -fd

                            echo "[INFO] Restoring local env/secret files..."
                            if [ -d "$LOCAL_FILES_DIR" ]; then
                                cp -a "$LOCAL_FILES_DIR"/. "$REPO_DIR"/
                            fi

                            echo "[INFO] Current local env/secret files:"
                            find "$REPO_DIR" -type f \\( -name "*.env" -o -name ".env" -o -name "*.secret" \\) -print || true

                            echo "[OK] GNS3 host repository is synced with GitHub source of truth and local env files restored."
                            git remote -v
                            git status
                        '
                    '''
                }
            }
        }

        stage('10A - Build FRR Docker Image on GNS3 Host') {
            /*
             * Purpose:
             * Build the FRR router image on the GNS3 host only when:
             * - docker/frr-ssh changed in AUTO mode
             * - or manual BUILD_IMAGES / PUSH_IMAGES / FULL_LOCAL_REFRESH is selected
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_FRR == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            set -e
                            cd /home/gns3/pfe-repo
                            docker build --network=host -t ${DOCKERHUB_NAMESPACE}/${FRR_IMAGE}:${IMAGE_TAG} docker/frr-ssh
                        "
                    '''
                }
            }
        }

        stage('10B - Build OVS Docker Image on GNS3 Host') {
            /*
             * Purpose:
             * Build the OVS switch image on the GNS3 host only when needed.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_OVS == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            set -e
                            cd /home/gns3/pfe-repo
                            docker build --network=host -t ${DOCKERHUB_NAMESPACE}/${OVS_IMAGE}:${IMAGE_TAG} docker/ovs-ssh
                        "
                    '''
                }
            }
        }

        stage('10C - Build Web Docker Image on GNS3 Host') {
            /*
             * Purpose:
             * Build the DMZ Web image on the GNS3 host only when needed.
             *
             * Web image uses repo root as Docker build context because
             * its Dockerfile copies files from outside docker/web-nginx/.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_WEB == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            set -e
                            cd /home/gns3/pfe-repo
                            docker build --network=host -f docker/web-nginx/Dockerfile \
                              -t ${DOCKERHUB_NAMESPACE}/${WEB_IMAGE}:${IMAGE_TAG} .
                        "
                    '''
                }
            }
        }

        stage('10D - Build DNS Docker Image on GNS3 Host') {
            /*
             * Purpose:
             * Build the DMZ DNS image on the GNS3 host only when needed.
             *
             * DNS image uses repo root as Docker build context because
             * its Dockerfile copies files from outside docker/dns/.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['BUILD_IMAGES', 'PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_DNS == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            set -e
                            cd /home/gns3/pfe-repo
                            docker build --network=host -f docker/dns/Dockerfile \
                              -t ${DOCKERHUB_NAMESPACE}/${DNS_IMAGE}:${IMAGE_TAG} .
                        "
                    '''
                }
            }
        }

        stage('11A - Docker Hub Login on GNS3 Host') {
            /*
             * Purpose:
             * Login to Docker Hub from the GNS3 host only if an image will be pushed.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && params.AUTO_PUSH_IMAGES && env.CHANGED_DOCKER_ANY == 'true')
                    )
                }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'gns3-host-ssh-key',
                        keyFileVariable: 'GNS3_KEY',
                        usernameVariable: 'GNS3_USER'
                    ),
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set -e

                        printf '%s' "$DOCKERHUB_TOKEN" | ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                          "docker login -u '$DOCKERHUB_USER' --password-stdin"
                    '''
                }
            }
        }

        stage('11B - Push FRR Image to Docker Hub') {
            /*
             * Purpose:
             * Push the FRR image from the GNS3 host to Docker Hub.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && params.AUTO_PUSH_IMAGES && env.CHANGED_DOCKER_FRR == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            docker push ${DOCKERHUB_NAMESPACE}/${FRR_IMAGE}:${IMAGE_TAG}
                        "
                    '''
                }
            }
        }

        stage('11C - Push OVS Image to Docker Hub') {
            /*
             * Purpose:
             * Push the OVS image from the GNS3 host to Docker Hub.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && params.AUTO_PUSH_IMAGES && env.CHANGED_DOCKER_OVS == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            docker push ${DOCKERHUB_NAMESPACE}/${OVS_IMAGE}:${IMAGE_TAG}
                        "
                    '''
                }
            }
        }

        stage('11D - Push Web Image to Docker Hub') {
            /*
             * Purpose:
             * Push the Web image from the GNS3 host to Docker Hub.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && params.AUTO_PUSH_IMAGES && env.CHANGED_DOCKER_WEB == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            docker push ${DOCKERHUB_NAMESPACE}/${WEB_IMAGE}:${IMAGE_TAG}
                        "
                    '''
                }
            }
        }

        stage('11E - Push DNS Image to Docker Hub') {
            /*
             * Purpose:
             * Push the DNS image from the GNS3 host to Docker Hub.
             */
            when {
                expression {
                    return (
                        params.PIPELINE_MODE in ['PUSH_IMAGES', 'FULL_LOCAL_REFRESH'] ||
                        (params.PIPELINE_MODE == 'AUTO' && params.AUTO_PUSH_IMAGES && env.CHANGED_DOCKER_DNS == 'true')
                    )
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" "
                            docker push ${DOCKERHUB_NAMESPACE}/${DNS_IMAGE}:${IMAGE_TAG}
                        "
                    '''
                }
            }
        }

        stage('12 - Check GNS3 Host and Node Status') {
            /*
             * Purpose:
             * Run a read-only health check on the GNS3 host.
             * This verifies Docker access and shows the state of GNS3 containers.
             *
             * Runs only for confirmed GNS3 maintenance modes.
             */
            when {
                expression {
                    return params.PIPELINE_MODE in ['BOOTSTRAP_GNS3', 'FULL_LOCAL_REFRESH'] && params.CONFIRM_APPLY
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" '
                            set -e
                            cd /home/gns3/pfe-repo
                            chmod +x gns3/scripts/gns3-status.sh
                            bash gns3/scripts/gns3-status.sh
                        '
                    '''
                }
            }
        }

        stage('13 - Bootstrap GNS3 Persistent Node Configs') {
            /*
             * Purpose:
             * Run the GNS3 bootstrap from the GNS3 host.
             *
             * This writes FRR/OVS/OOB/security configuration into persistent
             * Docker volumes so nodes can start/restart with correct config.
             *
             * This stage modifies the lab environment, so CONFIRM_APPLY is required.
             */
            when {
                expression {
                    return params.PIPELINE_MODE in ['BOOTSTRAP_GNS3', 'FULL_LOCAL_REFRESH'] && params.CONFIRM_APPLY
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'gns3-host-ssh-key',
                    keyFileVariable: 'GNS3_KEY',
                    usernameVariable: 'GNS3_USER'
                )]) {
                    sh '''
                        set -e

                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" '
                            set -e
                            cd /home/gns3/pfe-repo
                            chmod +x gns3/scripts/bootstrap-persistent-gns3.sh
                            bash gns3/scripts/bootstrap-persistent-gns3.sh
                        '
                    '''
                }
            }
        }

        stage('14 - Ansible Inventory Check') {
            /*
             * Purpose:
             * Validate that Ansible can parse the inventory and produce a graph/list.
             */
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        ansible-inventory --graph
                        ansible-inventory --list > outputs/jenkins-inventory.json
                    '''
                }
            }
        }

        stage('15 - Ansible Syntax Check') {
            /*
             * Purpose:
             * Validate playbook syntax before running any infrastructure validation.
             */
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        ansible-playbook --syntax-check playbooks/site.yml
                    '''
                }
            }
        }

        stage('16 - Run Local Topology Validation Gate') {
            /*
             * Purpose:
             * Validate the current running local topology through Ansible.
             *
             * This is your main safety gate:
             * - OOB reachability
             * - FRR/OVS checks
             * - DMZ checks
             * - security checks
             * - generated reports
             */
            steps {
                dir("${ANSIBLE_DIR}") {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'pfe-oob-root-key',
                        keyFileVariable: 'PFE_SSH_KEY',
                        usernameVariable: 'PFE_SSH_USER'
                    )]) {
                        sh '''
                            ansible-playbook playbooks/site.yml \
                              -e "ansible_user=${PFE_SSH_USER} ansible_ssh_private_key_file=${PFE_SSH_KEY}"
                        '''
                    }
                }
            }
        }

        stage('17 - Generate HTML Summary Report') {
            /*
             * Purpose:
             * Convert generated text reports into a simple HTML summary
             * for Jenkins artifacts and the Flask dashboard.
             */
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        python3 - <<'PY'
from pathlib import Path
from html import escape
from datetime import datetime

outputs = Path("outputs")
outputs.mkdir(exist_ok=True)
html_file = outputs / "index.html"

reports = sorted(outputs.glob("*.txt"))
critical_patterns = ["FAILED!", "fatal:", "UNREACHABLE!", "ERROR!", "Traceback"]

passed, failed, missing = [], [], []

for report in reports:
    content = report.read_text(errors="replace")
    if not content.strip():
        missing.append(report.name)
    elif any(pattern in content for pattern in critical_patterns):
        failed.append(report.name)
    else:
        passed.append(report.name)

status = "PASSED" if not failed and not missing else "FAILED"

rows = []
for report in reports:
    content = report.read_text(errors="replace")
    size_kb = round(report.stat().st_size / 1024, 2)

    if report.name in failed:
        state = "FAILED"
    elif report.name in missing:
        state = "MISSING"
    else:
        state = "PASSED"

    preview = "\\n".join(content.splitlines()[:18])

    rows.append(f"""
    <tr>
      <td>{escape(report.name)}</td>
      <td class="{state.lower()}">{state}</td>
      <td>{size_kb} KB</td>
      <td><pre>{escape(preview)}</pre></td>
    </tr>
    """)

html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>PFE Jenkins Validation Summary</title>
  <style>
    body {{ font-family: Arial, sans-serif; background: #f8fafc; color: #0f172a; padding: 32px; }}
    .hero, .card, table {{ background: white; border-radius: 16px; box-shadow: 0 8px 20px rgba(15, 23, 42, 0.08); }}
    .hero {{ padding: 24px; margin-bottom: 24px; }}
    .status {{ display: inline-block; padding: 8px 14px; border-radius: 999px; font-weight: bold; background: {"#dcfce7" if status == "PASSED" else "#fee2e2"}; color: {"#166534" if status == "PASSED" else "#991b1b"}; }}
    .cards {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }}
    .card {{ padding: 18px; }}
    .card span {{ color: #64748b; font-size: 13px; }}
    .card strong {{ display: block; font-size: 28px; margin-top: 8px; }}
    table {{ width: 100%; border-collapse: collapse; overflow: hidden; }}
    th, td {{ padding: 14px; border-bottom: 1px solid #e2e8f0; text-align: left; vertical-align: top; }}
    th {{ background: #e2e8f0; }}
    .passed {{ color: #166534; font-weight: bold; }}
    .failed {{ color: #991b1b; font-weight: bold; }}
    .missing {{ color: #92400e; font-weight: bold; }}
    pre {{ white-space: pre-wrap; max-height: 220px; overflow: auto; background: #f1f5f9; padding: 12px; border-radius: 12px; }}
  </style>
</head>
<body>
  <div class="hero">
    <h1>PFE Network Validation Summary</h1>
    <p>Generated by Jenkins on {escape(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))}</p>
    <span class="status">{status}</span>
  </div>

  <div class="cards">
    <div class="card"><span>Total reports</span><strong>{len(reports)}</strong></div>
    <div class="card"><span>Passed</span><strong>{len(passed)}</strong></div>
    <div class="card"><span>Failed</span><strong>{len(failed)}</strong></div>
    <div class="card"><span>Missing</span><strong>{len(missing)}</strong></div>
  </div>

  <table>
    <thead><tr><th>Report</th><th>Status</th><th>Size</th><th>Preview</th></tr></thead>
    <tbody>{''.join(rows)}</tbody>
  </table>
</body>
</html>
"""
html_file.write_text(html)
print(f"Generated {html_file}")
PY
                    '''
                }
            }
        }

        stage('18 - Publish Reports to Flask Dashboard') {
            /*
             * Purpose:
             * Copy the latest Jenkins/Ansible reports into the dashboard output folder.
             *
             * This updates the dashboard content automatically after every validation.
             */
            when {
                expression {
                    return params.PUBLISH_DASHBOARD
                }
            }
            steps {
                sh '''
                    mkdir -p "$DASHBOARD_OUTPUTS_DIR"
                    rsync -a --delete ansible/outputs/ "$DASHBOARD_OUTPUTS_DIR/"
                    echo "[OK] Latest reports copied to $DASHBOARD_OUTPUTS_DIR"
                    ls -lah "$DASHBOARD_OUTPUTS_DIR"
                '''
            }
        }

        stage('19 - Upload Validation Artifacts to AWS S3') {
            /*
            * Purpose:
            * Export Jenkins/Ansible validation artifacts to the AWS S3 artifacts bucket.
            *
            * This implements the first safe cloud integration path:
            * local validation outputs -> private S3 bucket.
            *
            * VPN remains disabled. Upload is done through outbound HTTPS using AWS CLI.
            */
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-pfe-artifacts-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        set -e

                        if [ "$S3_ARTIFACTS_BUCKET" = "CHANGE_ME" ] || [ -z "$S3_ARTIFACTS_BUCKET" ]; then
                            echo "[ERROR] S3_ARTIFACTS_BUCKET must be set when EXPORT_ARTIFACTS_TO_S3=true."
                            exit 1
                        fi

                        if ! command -v aws >/dev/null 2>&1; then
                            echo "[ERROR] AWS CLI is not installed or not available to the Jenkins user."
                            exit 1
                        fi

                        chmod +x cloud/scripts/upload-validation-artifacts-s3.sh

                        AWS_REGION="${CLOUD_AWS_REGION}" \
                        ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET}" \
                        BUILD_TAG="${JOB_NAME}-${BUILD_NUMBER}" \
                        ./cloud/scripts/upload-validation-artifacts-s3.sh
                    '''

                    script {
                        env.S3_ARTIFACTS_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/validation-artifacts/${env.JOB_NAME}-${env.BUILD_NUMBER}/"

                        currentBuild.description = """${currentBuild.description ?: ''}
                    S3 artifacts: ${env.S3_ARTIFACTS_URI}
                    """
                    }
                }
            }
        }

        stage('20 - Run Cloud Analyzer and Upload Results') {
            /*
            * Purpose:
            * Run the cloud anomaly baseline analyzer on Jenkins/Ansible validation outputs.
            *
            * This creates:
            * - summary.json
            * - decision.json
            * - analysis-report.txt
            *
            * Then uploads them to S3 under:
            * - processed-summaries/<build>/
            * - anomaly-results/<build>/
            * - latest/
            */
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-pfe-artifacts-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        set -e

                        if [ "$S3_ARTIFACTS_BUCKET" = "CHANGE_ME" ] || [ -z "$S3_ARTIFACTS_BUCKET" ]; then
                            echo "[ERROR] S3_ARTIFACTS_BUCKET must be set when EXPORT_ARTIFACTS_TO_S3=true."
                            exit 1
                        fi

                        BUILD_LABEL="${JOB_NAME}-${BUILD_NUMBER}"
                        ANALYZER_OUTPUT_DIR="cloud/analyzer/outputs/${BUILD_LABEL}"

                        echo "[INFO] Running cloud analyzer for ${BUILD_LABEL}..."

                        python3 cloud/analyzer/analyze_validation_artifacts.py \
                        --input-dir ansible/outputs \
                        --output-dir "$ANALYZER_OUTPUT_DIR" \
                        --build-label "$BUILD_LABEL"

                        echo "[INFO] Analyzer output:"
                        ls -lah "$ANALYZER_OUTPUT_DIR"

                        echo "[INFO] Uploading processed summary to S3..."
                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                        "s3://${S3_ARTIFACTS_BUCKET}/processed-summaries/${BUILD_LABEL}/" \
                        --region "$CLOUD_AWS_REGION"

                        echo "[INFO] Uploading anomaly decision to S3..."
                        aws s3 cp "$ANALYZER_OUTPUT_DIR/decision.json" \
                        "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/decision.json" \
                        --region "$CLOUD_AWS_REGION"

                        aws s3 cp "$ANALYZER_OUTPUT_DIR/analysis-report.txt" \
                        "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/analysis-report.txt" \
                        --region "$CLOUD_AWS_REGION"

                        echo "[INFO] Updating latest analyzer outputs..."
                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                        "s3://${S3_ARTIFACTS_BUCKET}/latest/analyzer/" \
                        --region "$CLOUD_AWS_REGION" \
                        --delete

                        echo "[OK] Cloud analyzer results uploaded."
                    '''

                    script {
                        env.S3_ANALYZER_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/anomaly-results/${env.JOB_NAME}-${env.BUILD_NUMBER}/"

                        currentBuild.description = """${currentBuild.description ?: ''}
        Analyzer results: ${env.S3_ANALYZER_URI}
        """
                    }
                }
            }
        }

        stage('21 - Sync Dashboard Cache from AWS S3') {
            /*
            * Purpose:
            * Make the local Flask dashboard cloud-backed.
            *
            * S3 is the source of truth.
            * Local ansible/outputs and cloud/analyzer/outputs/latest are only cache.
            */
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-pfe-artifacts-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        set -e

                        if [ "$S3_ARTIFACTS_BUCKET" = "CHANGE_ME" ] || [ -z "$S3_ARTIFACTS_BUCKET" ]; then
                            echo "[ERROR] S3_ARTIFACTS_BUCKET must be set when EXPORT_ARTIFACTS_TO_S3=true."
                            exit 1
                        fi

                        chmod +x cloud/scripts/sync-dashboard-cache-from-s3.sh

                        AWS_REGION="${CLOUD_AWS_REGION}" \
                        ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET}" \
                        ANSIBLE_OUTPUTS_DIR="/var/lib/pfe-dashboard/outputs" \
                        ANALYZER_LATEST_DIR="/var/lib/pfe-dashboard/analyzer/latest" \
                        ./cloud/scripts/sync-dashboard-cache-from-s3.sh
                    '''
                }
            }
        }

        stage('22 - Show Generated Reports') {
            /*
             * Purpose:
             * Print the generated artifacts in the Jenkins console for quick verification.
             */
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        echo "Generated reports:"
                        ls -lah outputs/
                    '''
                }
            }
        }

        stage('22 - Set Jenkins Build Description') {
            /*
             * Purpose:
             * Add direct dashboard/artifact links to the Jenkins build page.
             */
            steps {
                script {
                    def s3Line = env.S3_ARTIFACTS_URI ? "S3 artifacts: ${env.S3_ARTIFACTS_URI}" : "S3 artifacts: disabled"
                    def analyzerLine = env.S3_ANALYZER_URI ? "Analyzer results: ${env.S3_ANALYZER_URI}" : "Analyzer results: disabled"

                    currentBuild.description = """Mode: ${params.PIPELINE_MODE}
Dashboard: ${env.DASHBOARD_URL}
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html
Reports folder: ${env.DASHBOARD_OUTPUTS_DIR}
${s3Line}
${analyzerLine}
"""
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'ansible/outputs/**/*', fingerprint: true, allowEmptyArchive: true
        }

        success {
            script {
                def s3Line = env.S3_ARTIFACTS_URI ? "S3 artifacts: ${env.S3_ARTIFACTS_URI}" : "S3 artifacts: disabled"
                def analyzerLine = env.S3_ANALYZER_URI ? "Analyzer results: ${env.S3_ANALYZER_URI}" : "Analyzer results: disabled"

                currentBuild.description = """SUCCESS - ${params.PIPELINE_MODE}
Dashboard: ${env.DASHBOARD_URL}
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html
Reports folder: ${env.DASHBOARD_OUTPUTS_DIR}
${s3Line}
${analyzerLine}
"""
            }
            echo 'PFE local automation pipeline completed successfully.'
        }

        failure {
            script {
                def s3Line = env.S3_ARTIFACTS_URI ? "S3 artifacts: ${env.S3_ARTIFACTS_URI}" : "S3 artifacts: not uploaded"

                currentBuild.description = """FAILED - ${params.PIPELINE_MODE}
Check console output and archived artifacts.
HTML summary if generated: ${env.BUILD_URL}artifact/ansible/outputs/index.html
${s3Line}
"""
            }
            echo 'PFE local automation pipeline failed. Check Jenkins console output and reports.'
        }
    }
}