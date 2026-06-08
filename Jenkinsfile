pipeline {
    agent any

    /*
     * Local Enterprise-Like Automation Pipeline
     *
     * Jenkins runs on the DevOps VM.
     * Docker image build/push is delegated to the GNS3 VM/host through SSH,
     * because Docker is installed on the GNS3 VM, not on the DevOps VM.
     *
     * Default AUTO mode is safe for GitHub push triggers / local trigger bridge.
     * GNS3 bootstrap actions require CONFIRM_APPLY.
     *
     * Full automation flow:
     * Validation -> S3 -> Prometheus metrics snapshot -> S3
     * -> Rule analyzer -> S3
     * -> ML historical dataset -> Isolation Forest -> ML decision -> S3
     * -> Hybrid final decision -> S3
     * -> Safe remediation plan/apply -> S3
     * -> /var/lib/pfe-dashboard cache sync
     */

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 60, unit: 'MINUTES')
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
            description: 'Required only for actions that modify the GNS3 host/topology state or safe remediation apply mode.'
        )

        booleanParam(
            name: 'AUTO_PUSH_IMAGES',
            defaultValue: true,
            description: 'In AUTO mode, push changed Docker images to Docker Hub after successful build.'
        )

        string(
            name: 'DOCKERHUB_NAMESPACE',
            defaultValue: 'vviam',
            description: 'Docker Hub namespace/user where images will be pushed.'
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
            description: 'Keep true. Dashboard cache is synchronized from S3 into /var/lib/pfe-dashboard.'
        )

        booleanParam(
            name: 'EXPORT_ARTIFACTS_TO_S3',
            defaultValue: false,
            description: 'Upload validation, metrics, analyzer, ML, final decision and remediation outputs to S3.'
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

        booleanParam(
            name: 'ENABLE_ML_ANALYZER',
            defaultValue: true,
            description: 'Run the ML Isolation Forest analyzer after the rule-based analyzer.'
        )

        booleanParam(
            name: 'TRAIN_ML_MODEL',
            defaultValue: false,
            description: 'Retrain the Isolation Forest model during this build. If false, Jenkins trains only when no persisted model exists.'
        )

        string(
            name: 'ML_DURATION_MINUTES',
            defaultValue: '60',
            description: 'Historical Prometheus window duration used for ML feature collection.'
        )

        string(
            name: 'ML_STEP',
            defaultValue: '60s',
            description: 'Prometheus query_range step used for ML feature collection.'
        )

        string(
            name: 'ML_CONTAMINATION',
            defaultValue: '0.05',
            description: 'Expected anomaly ratio used when training Isolation Forest.'
        )

        booleanParam(
            name: 'ENABLE_SAFE_REMEDIATION',
            defaultValue: true,
            description: 'Generate remediation plan after final hybrid decision.'
        )

        choice(
            name: 'REMEDIATION_MODE',
            choices: [
                'plan',
                'apply'
            ],
            description: 'plan does not execute changes. apply executes allowlisted actions and requires CONFIRM_APPLY.'
        )

        string(
            name: 'REMEDIATION_ACTION',
            defaultValue: 'auto',
            description: 'Safe remediation action to run. Use auto for decision-based selection.'
        )
    }

    environment {
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_HOST_KEY_CHECKING = 'False'

        DASHBOARD_BASE_DIR = '/var/lib/pfe-dashboard'
        DASHBOARD_OUTPUTS_DIR = '/var/lib/pfe-dashboard/outputs'
        DASHBOARD_ANALYZER_DIR = '/var/lib/pfe-dashboard/analyzer/latest'
        DASHBOARD_METRICS_DIR = '/var/lib/pfe-dashboard/metrics/latest'
        DASHBOARD_ML_DIR = '/var/lib/pfe-dashboard/ml/latest'
        DASHBOARD_REMEDIATION_DIR = '/var/lib/pfe-dashboard/remediation/latest'
        DASHBOARD_URL = 'http://10.200.0.10:5050'

        ML_RUNTIME_DIR = '/var/lib/pfe-dashboard/ml'
        ML_MODEL_DIR = '/var/lib/pfe-dashboard/ml/models'

        FRR_IMAGE = 'pfe-frr-ssh'
        OVS_IMAGE = 'pfe-ovs-ssh'
        WEB_IMAGE = 'pfe-web-nginx'
        DNS_IMAGE = 'pfe-dns'
    }

    stages {
        stage('01 - Clean Jenkins Workspace') {
            steps {
                deleteDir()
            }
        }

        stage('02 - Checkout Repository') {
            steps {
                checkout scm
            }
        }

        stage('03 - Set Runtime Build Paths') {
            steps {
                script {
                    env.BUILD_LABEL = "${env.JOB_NAME}-${env.BUILD_NUMBER}"
                    env.ANALYZER_OUTPUT_DIR = "cloud/analyzer/outputs/${env.BUILD_LABEL}"
                    env.REMEDIATION_OUTPUT_DIR = "${env.ANALYZER_OUTPUT_DIR}/remediation"
                    env.ML_OUTPUT_DIR = "cloud/analyzer/ml/outputs"
                    env.ML_FEATURE_CSV = "cloud/analyzer/ml/data/features/latest_features.csv"
                    env.ML_RAW_DIR = "cloud/analyzer/ml/data/raw/latest"
                }
            }
        }

        stage('04 - Show Execution Environment') {
            steps {
                sh '''
                    echo "Workspace: $WORKSPACE"
                    echo "User: $(whoami)"
                    echo "Host: $(hostname)"
                    echo "Build label: ${BUILD_LABEL}"
                    echo "Pipeline mode: ${PIPELINE_MODE}"
                    echo "Docker namespace: ${DOCKERHUB_NAMESPACE}"
                    echo "Image tag: ${IMAGE_TAG}"
                    echo "ML analyzer enabled: ${ENABLE_ML_ANALYZER}"
                    echo "Safe remediation enabled: ${ENABLE_SAFE_REMEDIATION}"
                    echo "Remediation mode: ${REMEDIATION_MODE}"
                    echo "Dashboard base dir: ${DASHBOARD_BASE_DIR}"

                    git --version
                    ansible --version
                    ansible-playbook --version
                    python3 --version

                    echo "[INFO] Local Jenkins does not need Docker. Docker work is delegated to the GNS3 host."
                '''
            }
        }

        stage('05 - Detect Changed Areas') {
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
                    env.CHANGED_ANALYZER = changedFiles.contains('cloud/analyzer/') ? 'true' : 'false'
                    env.CHANGED_MONITORING = changedFiles.contains('monitoring/') ? 'true' : 'false'

                    echo "CHANGED_DOCKER_FRR=${env.CHANGED_DOCKER_FRR}"
                    echo "CHANGED_DOCKER_OVS=${env.CHANGED_DOCKER_OVS}"
                    echo "CHANGED_DOCKER_WEB=${env.CHANGED_DOCKER_WEB}"
                    echo "CHANGED_DOCKER_DNS=${env.CHANGED_DOCKER_DNS}"
                    echo "CHANGED_DOCKER_ANY=${env.CHANGED_DOCKER_ANY}"
                    echo "CHANGED_GNS3=${env.CHANGED_GNS3}"
                    echo "CHANGED_ANSIBLE=${env.CHANGED_ANSIBLE}"
                    echo "CHANGED_DASHBOARD=${env.CHANGED_DASHBOARD}"
                    echo "CHANGED_JENKINS=${env.CHANGED_JENKINS}"
                    echo "CHANGED_ANALYZER=${env.CHANGED_ANALYZER}"
                    echo "CHANGED_MONITORING=${env.CHANGED_MONITORING}"
                }
            }
        }

        stage('06 - Safety Guard for GNS3 Apply Modes') {
            when {
                expression {
                    return params.PIPELINE_MODE in ['BOOTSTRAP_GNS3', 'FULL_LOCAL_REFRESH'] && !params.CONFIRM_APPLY
                }
            }
            steps {
                error('[SAFETY] CONFIRM_APPLY must be checked for BOOTSTRAP_GNS3 or FULL_LOCAL_REFRESH.')
            }
        }

        stage('07 - Safety Guard for GNS3 Host Requirement') {
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

        stage('08 - Safety Guard for Safe Remediation Apply Mode') {
            when {
                expression {
                    return params.ENABLE_SAFE_REMEDIATION && params.REMEDIATION_MODE == 'apply' && !params.CONFIRM_APPLY
                }
            }
            steps {
                error('[SAFETY] Safe remediation apply mode requires CONFIRM_APPLY=true.')
            }
        }

        stage('09 - Prepare Shared Dashboard and ML Folders') {
            steps {
                sh '''
                    set -e

                    mkdir -p "${DASHBOARD_OUTPUTS_DIR}" \
                             "${DASHBOARD_ANALYZER_DIR}" \
                             "${DASHBOARD_METRICS_DIR}" \
                             "${DASHBOARD_ML_DIR}" \
                             "${DASHBOARD_REMEDIATION_DIR}" \
                             "${ML_RUNTIME_DIR}/data" \
                             "${ML_RUNTIME_DIR}/outputs" \
                             "${ML_MODEL_DIR}"

                    if [ ! -w "${DASHBOARD_BASE_DIR}" ]; then
                        echo "[ERROR] Jenkins cannot write to ${DASHBOARD_BASE_DIR}"
                        echo "[INFO] Fix on DevOps VM:"
                        echo "sudo mkdir -p ${DASHBOARD_BASE_DIR}"
                        echo "sudo chown -R jenkins:jenkins ${DASHBOARD_BASE_DIR}"
                        exit 1
                    fi

                    echo "[OK] Shared folder ready: ${DASHBOARD_BASE_DIR}"
                '''
            }
        }

        stage('10 - Prepare Ansible Output Directory') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        rm -rf outputs
                        mkdir -p outputs
                    '''
                }
            }
        }

        stage('11 - Check GNS3 Host Access') {
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

        stage('12 - Sync Repo on GNS3 Host') {
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

        stage('13A - Build FRR Docker Image on GNS3 Host') {
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

        stage('13B - Build OVS Docker Image on GNS3 Host') {
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

        stage('13C - Build Web Docker Image on GNS3 Host') {
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

        stage('13D - Build DNS Docker Image on GNS3 Host') {
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

        stage('14A - Docker Hub Login on GNS3 Host') {
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

        stage('14B - Push FRR Image to Docker Hub') {
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
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                            "docker push ${DOCKERHUB_NAMESPACE}/${FRR_IMAGE}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('14C - Push OVS Image to Docker Hub') {
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
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                            "docker push ${DOCKERHUB_NAMESPACE}/${OVS_IMAGE}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('14D - Push Web Image to Docker Hub') {
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
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                            "docker push ${DOCKERHUB_NAMESPACE}/${WEB_IMAGE}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('14E - Push DNS Image to Docker Hub') {
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
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                            "docker push ${DOCKERHUB_NAMESPACE}/${DNS_IMAGE}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('15 - Check GNS3 Host and Node Status') {
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

        stage('16 - Bootstrap GNS3 Persistent Node Configs') {
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

        stage('17 - Ansible Inventory Check') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        ansible-inventory --graph
                        ansible-inventory --list > outputs/jenkins-inventory.json
                    '''
                }
            }
        }

        stage('18 - Ansible Syntax Check') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        ansible-playbook --syntax-check playbooks/site.yml
                    '''
                }
            }
        }

        stage('19 - Run Local Topology Validation Gate') {
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

        stage('20 - Generate HTML Summary Report') {
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
  <td><strong>{state}</strong></td>
  <td>{size_kb} KB</td>
  <td><pre>{escape(preview)}</pre></td>
</tr>
""")

html = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>PFE Jenkins Validation Summary</title>
  <style>
    body {{
      font-family: Arial, sans-serif;
      margin: 30px;
      background: #f6f8fa;
      color: #24292f;
    }}
    .card {{
      background: white;
      border: 1px solid #d0d7de;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 20px;
    }}
    .status {{
      font-size: 24px;
      font-weight: bold;
    }}
    .PASSED {{
      color: #1a7f37;
    }}
    .FAILED {{
      color: #cf222e;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      background: white;
    }}
    th, td {{
      border: 1px solid #d0d7de;
      padding: 8px;
      vertical-align: top;
    }}
    th {{
      background: #f3f4f6;
    }}
    pre {{
      white-space: pre-wrap;
      max-height: 260px;
      overflow: auto;
      background: #f6f8fa;
      padding: 8px;
      border-radius: 6px;
    }}
  </style>
</head>
<body>
  <div class="card">
    <h1>PFE Network Validation Summary</h1>
    <p>Generated by Jenkins on {escape(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))}</p>
    <p class="status {status}">{status}</p>
    <p>Total reports: {len(reports)}</p>
    <p>Passed: {len(passed)}</p>
    <p>Failed: {len(failed)}</p>
    <p>Missing: {len(missing)}</p>
  </div>

  <table>
    <tr>
      <th>Report</th>
      <th>Status</th>
      <th>Size</th>
      <th>Preview</th>
    </tr>
    {''.join(rows)}
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

        stage('21 - Validate Generated Dashboard Reports') {
            steps {
                sh '''
                    set -e

                    echo "[INFO] Validating generated report files in Jenkins workspace..."

                    if [ ! -d "ansible/outputs" ]; then
                        echo "[ERROR] ansible/outputs directory does not exist."
                        exit 1
                    fi

                    if [ -z "$(ls -A ansible/outputs 2>/dev/null)" ]; then
                        echo "[ERROR] ansible/outputs directory is empty."
                        exit 1
                    fi

                    if [ ! -f "ansible/outputs/validation-summary.txt" ]; then
                        echo "[ERROR] validation-summary.txt is missing."
                        exit 1
                    fi

                    echo "[OK] Jenkins workspace reports are ready."
                    ls -lah ansible/outputs
                '''
            }
        }

        stage('22 - Upload Validation Artifacts to AWS S3') {
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
                        BUILD_TAG="${BUILD_LABEL}" \
                        ./cloud/scripts/upload-validation-artifacts-s3.sh
                    '''

                    script {
                        env.S3_ARTIFACTS_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/validation-artifacts/${env.BUILD_LABEL}/"
                    }
                }
            }
        }

        stage('23 - Apply Prometheus Target Configuration') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                sh '''
                    set -e

                    TARGET_SRC_DIR="monitoring/prometheus/targets"
                    TARGET_DST_DIR="/etc/prometheus/targets"

                    echo "[INFO] Applying Prometheus target configuration..."

                    if [ ! -d "$TARGET_SRC_DIR" ]; then
                        echo "[ERROR] Missing Prometheus target directory: $TARGET_SRC_DIR"
                        exit 1
                    fi

                    if [ ! -d "$TARGET_DST_DIR" ]; then
                        echo "[ERROR] $TARGET_DST_DIR does not exist."
                        echo "[INFO] Run monitoring/scripts/apply-local-prometheus-baseline.sh once on the DevOps VM."
                        exit 1
                    fi

                    umask 002

                    for file in "$TARGET_SRC_DIR"/*.yml; do
                        name="$(basename "$file")"
                        echo "[INFO] Applying target file: $name"
                        cp "$file" "$TARGET_DST_DIR/$name.tmp"
                        mv "$TARGET_DST_DIR/$name.tmp" "$TARGET_DST_DIR/$name"
                    done

                    echo "[INFO] Checking Prometheus readiness..."
                    curl -fsS http://localhost:9090/-/ready
                    echo

                    echo "[INFO] Waiting for Prometheus file_sd refresh..."
                    sleep 35

                    echo "[INFO] Current Prometheus target health:"
                    curl -fsS --get "http://localhost:9090/api/v1/query" \
                        --data-urlencode "query=up" | python3 -m json.tool

                    echo "[OK] Prometheus target configuration applied."
                '''
            }
        }

        stage('24 - Export Prometheus Metrics Snapshot') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                sh '''
                    set -e

                    if ! command -v curl >/dev/null 2>&1; then
                        echo "[ERROR] curl is required to query Prometheus."
                        exit 1
                    fi

                    echo "[INFO] Checking Prometheus readiness..."
                    curl -fsS http://localhost:9090/-/ready

                    chmod +x monitoring/scripts/export-prometheus-snapshot.sh

                    echo "[INFO] Exporting Prometheus metrics snapshot to Jenkins workspace..."
                    PROMETHEUS_URL="http://localhost:9090" \
                    OUTPUT_DIR="monitoring/outputs/latest" \
                    ./monitoring/scripts/export-prometheus-snapshot.sh

                    echo "[INFO] Metrics snapshot output:"
                    find monitoring/outputs/latest -maxdepth 1 -type f -print | sort
                '''
            }
        }

        stage('25 - Upload Prometheus Metrics Snapshot to AWS S3') {
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

                        chmod +x cloud/scripts/upload-prometheus-snapshot-s3.sh

                        AWS_REGION="${CLOUD_AWS_REGION}" \
                        ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET}" \
                        METRICS_SNAPSHOT_DIR="monitoring/outputs/latest" \
                        BUILD_TAG="${BUILD_LABEL}" \
                        ./cloud/scripts/upload-prometheus-snapshot-s3.sh
                    '''

                    script {
                        env.S3_METRICS_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/metrics-snapshots/${env.BUILD_LABEL}/"
                    }
                }
            }
        }

        stage('26 - Run Rule-Based Cloud Analyzer') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                sh '''
                    set -e

                    echo "[INFO] Running rule-based cloud analyzer for ${BUILD_LABEL}..."

                    python3 cloud/analyzer/analyze_validation_artifacts.py \
                        --input-dir ansible/outputs \
                        --metrics-dir monitoring/outputs/latest \
                        --output-dir "$ANALYZER_OUTPUT_DIR" \
                        --build-label "$BUILD_LABEL"

                    echo "[INFO] Rule-based analyzer output:"
                    ls -lah "$ANALYZER_OUTPUT_DIR"

                    test -f "$ANALYZER_OUTPUT_DIR/summary.json"
                    test -f "$ANALYZER_OUTPUT_DIR/decision.json"
                    test -f "$ANALYZER_OUTPUT_DIR/analysis-report.txt"
                '''
            }
        }

        stage('27 - Upload Rule-Based Analyzer Results to AWS S3') {
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

                        echo "[INFO] Uploading rule-based analyzer outputs to S3..."

                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/processed-summaries/${BUILD_LABEL}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/analyzer/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete
                    '''

                    script {
                        env.S3_ANALYZER_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/anomaly-results/${env.BUILD_LABEL}/"
                    }
                }
            }
        }

        stage('28 - Prepare ML Runtime') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_ML_ANALYZER
                }
            }
            steps {
                sh '''
                    set -e

                    echo "[INFO] Preparing Python virtual environment for ML..."

                    if ! python3 -m venv --help >/dev/null 2>&1; then
                        echo "[ERROR] python3-venv is not installed."
                        echo "[INFO] Fix on DevOps VM:"
                        echo "sudo apt-get install -y python3-venv python3-full"
                        exit 1
                    fi

                    python3 -m venv .venv
                    . .venv/bin/activate

                    python -m pip install --upgrade pip
                    python -m pip install -r cloud/analyzer/ml/requirements.txt

                    mkdir -p cloud/analyzer/ml/data/raw/latest
                    mkdir -p cloud/analyzer/ml/data/features
                    mkdir -p cloud/analyzer/ml/outputs
                    mkdir -p "$ML_MODEL_DIR"

                    echo "[OK] ML runtime is ready."
                '''
            }
        }

        stage('29 - Collect Historical Prometheus Metrics for ML') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_ML_ANALYZER
                }
            }
            steps {
                sh '''
                    set -e
                    . .venv/bin/activate

                    ML_WINDOW_MINUTES="${ML_DURATION_MINUTES:-60}"
                    ML_QUERY_STEP="${ML_STEP:-60s}"

                    if ! echo "$ML_WINDOW_MINUTES" | grep -Eq '^[0-9]+$'; then
                        echo "[WARN] Invalid ML_DURATION_MINUTES='$ML_DURATION_MINUTES'. Falling back to 60."
                        ML_WINDOW_MINUTES="60"
                    fi

                    if [ -z "$ML_QUERY_STEP" ]; then
                        echo "[WARN] Empty ML_STEP. Falling back to 60s."
                        ML_QUERY_STEP="60s"
                    fi

                    echo "[INFO] Collecting Prometheus historical metrics for ML..."
                    echo "[INFO] Duration: ${ML_WINDOW_MINUTES} minutes"
                    echo "[INFO] Step: ${ML_QUERY_STEP}"

                    python cloud/analyzer/ml/collect_prometheus_window.py \
                        --prometheus-url http://localhost:9090 \
                        --duration-minutes "$ML_WINDOW_MINUTES" \
                        --step "$ML_QUERY_STEP" \
                        --output-dir "$ML_RAW_DIR"

                    echo "[INFO] Raw ML metric window:"
                    find "$ML_RAW_DIR" -maxdepth 1 -type f -print | sort | head -n 80
                '''
            }
        }

        stage('30 - Build ML Feature Dataset') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_ML_ANALYZER
                }
            }
            steps {
                sh '''
                    set -e
                    . .venv/bin/activate

                    echo "[INFO] Building ML feature dataset..."

                    python cloud/analyzer/ml/build_feature_dataset.py \
                        --raw-dir "$ML_RAW_DIR" \
                        --output-csv "$ML_FEATURE_CSV"

                    echo "[INFO] ML dataset preview:"
                    head -n 5 "$ML_FEATURE_CSV"
                    wc -l "$ML_FEATURE_CSV"

                    cp "$ML_FEATURE_CSV" "$ML_RUNTIME_DIR/data/latest_features.csv"
                '''
            }
        }

        stage('31 - Train or Reuse Isolation Forest Model') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_ML_ANALYZER
                }
            }
            steps {
                sh '''
                    set -e
                    . .venv/bin/activate

                    ML_CONTAMINATION_VALUE="${ML_CONTAMINATION:-0.05}"

                    if [ -z "$ML_CONTAMINATION_VALUE" ]; then
                        echo "[WARN] Empty ML_CONTAMINATION. Falling back to 0.05."
                        ML_CONTAMINATION_VALUE="0.05"
                    fi

                    if [ "$TRAIN_ML_MODEL" = "true" ] || [ ! -f "$ML_MODEL_DIR/isolation_forest.joblib" ]; then
                        echo "[INFO] Training Isolation Forest model..."
                        echo "[INFO] Contamination: ${ML_CONTAMINATION_VALUE}"

                        python cloud/analyzer/ml/train_isolation_forest.py \
                            --input-csv "$ML_FEATURE_CSV" \
                            --model-dir "$ML_MODEL_DIR" \
                            --output-dir "$ML_RUNTIME_DIR/outputs/training" \
                            --contamination "$ML_CONTAMINATION_VALUE"
                    else
                        echo "[INFO] Reusing existing persisted ML model:"
                        echo "$ML_MODEL_DIR/isolation_forest.joblib"
                    fi

                    test -f "$ML_MODEL_DIR/isolation_forest.joblib"
                    test -f "$ML_MODEL_DIR/training_metadata.json"
                    test -f "$ML_MODEL_DIR/feature_columns.json"

                    echo "[OK] ML model is available."
                '''
            }
        }

        stage('32 - Run ML Anomaly Prediction') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_ML_ANALYZER
                }
            }
            steps {
                sh '''
                    set -e
                    . .venv/bin/activate

                    echo "[INFO] Running ML anomaly prediction..."

                    python cloud/analyzer/ml/predict_anomaly.py \
                        --input-csv "$ML_FEATURE_CSV" \
                        --model-path "$ML_MODEL_DIR/isolation_forest.joblib" \
                        --metadata-path "$ML_MODEL_DIR/training_metadata.json" \
                        --output-dir "$ML_OUTPUT_DIR"

                    echo "[INFO] ML decision:"
                    python3 -m json.tool "$ML_OUTPUT_DIR/ml-decision.json" || cat "$ML_OUTPUT_DIR/ml-decision.json"

                    cp "$ML_OUTPUT_DIR/ml-decision.json" "$ML_RUNTIME_DIR/outputs/ml-decision.json"
                    cp "$ML_OUTPUT_DIR/ml-scores.csv" "$ML_RUNTIME_DIR/outputs/ml-scores.csv"
                '''
            }
        }

        stage('33 - Upload ML Dataset, Model and Decision to AWS S3') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_ML_ANALYZER
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

                        echo "[INFO] Uploading ML dataset to S3..."
                        aws s3 cp "$ML_FEATURE_CSV" \
                            "s3://${S3_ARTIFACTS_BUCKET}/ml-datasets/${BUILD_LABEL}/latest_features.csv" \
                            --region "$CLOUD_AWS_REGION"

                        aws s3 cp "$ML_FEATURE_CSV" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/ml-dataset/latest_features.csv" \
                            --region "$CLOUD_AWS_REGION"

                        echo "[INFO] Uploading ML decision outputs to S3..."
                        aws s3 sync "$ML_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/ml-results/${BUILD_LABEL}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$ML_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/ml/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        echo "[INFO] Uploading ML model metadata to S3..."
                        aws s3 sync "$ML_MODEL_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/ml-models/latest/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete
                    '''

                    script {
                        env.S3_ML_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/ml-results/${env.BUILD_LABEL}/"
                        env.S3_ML_DATASET_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/ml-datasets/${env.BUILD_LABEL}/latest_features.csv"
                    }
                }
            }
        }

        stage('34 - Merge Rule-Based and ML Decisions') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                sh '''
                    set -e

                    if [ "$ENABLE_ML_ANALYZER" = "true" ]; then
                        echo "[INFO] Merging rule-based and ML decisions..."

                        . .venv/bin/activate

                        python cloud/analyzer/ml/merge_ml_decision.py \
                            --rule-decision "$ANALYZER_OUTPUT_DIR/decision.json" \
                            --ml-decision "$ML_OUTPUT_DIR/ml-decision.json" \
                            --output-dir "$ANALYZER_OUTPUT_DIR"
                    else
                        echo "[WARN] ENABLE_ML_ANALYZER=false."
                        echo "[INFO] Creating rule-only final-decision.json fallback."

                        python3 - <<PY
import json
from pathlib import Path
from datetime import datetime, timezone

analyzer_dir = Path("$ANALYZER_OUTPUT_DIR")
decision_path = analyzer_dir / "decision.json"
final_path = analyzer_dir / "final-decision.json"
report_path = analyzer_dir / "final-decision-report.txt"

rule = json.loads(decision_path.read_text())

risk = int(round(float(rule.get("risk_score", rule.get("global_risk_score", 0)))))
status = str(rule.get("anomaly_status", "normal")).lower()
severity = str(rule.get("severity", "low")).lower()
action = str(rule.get("recommended_action", "no_action"))

rule_anomalous = status not in ["normal", "healthy", "ok"] or risk >= 25

final = {
    "project": "network-automation-platform",
    "engine": "rule_only_fallback_decision",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "merged_decision": {
        "classification": "rule_based_anomaly" if rule_anomalous else "normal",
        "final_status": "anomalous" if rule_anomalous else "normal",
        "final_severity": severity,
        "final_risk_score": risk,
        "confidence": "medium" if rule_anomalous else "high",
        "recommended_action": action if rule_anomalous else "no_action",
        "remediation_allowed": bool(rule_anomalous and action != "no_action"),
        "remediation_mode": "controlled_rule_based_remediation" if rule_anomalous and action != "no_action" else "no_remediation_needed",
        "decision_reason": "ML analyzer disabled. Final decision is based on the rule-based analyzer only.",
        "rule_anomalous": rule_anomalous,
        "ml_anomalous": False,
        "ml_suspicious": False
    },
    "rule_engine": rule,
    "ml_engine": {
        "available": False,
        "reason": "ENABLE_ML_ANALYZER=false"
    },
    "safety_policy": {
        "ml_is_advisory": True,
        "automated_remediation_requires_rule_confirmation": True
    }
}

final_path.write_text(json.dumps(final, indent=2, sort_keys=True))
report_path.write_text(
    "PFE Final Anomaly Decision Report\\n"
    "=================================\\n\\n"
    "ML analyzer disabled. Rule-only fallback decision was generated.\\n"
    f"Risk score: {risk}/100\\n"
    f"Status: {final['merged_decision']['final_status']}\\n"
    f"Recommended action: {final['merged_decision']['recommended_action']}\\n"
)
PY
                    fi

                    test -f "$ANALYZER_OUTPUT_DIR/final-decision.json"
                    test -f "$ANALYZER_OUTPUT_DIR/final-decision-report.txt"

                    echo "[INFO] Final hybrid decision:"
                    python3 -m json.tool "$ANALYZER_OUTPUT_DIR/final-decision.json" || cat "$ANALYZER_OUTPUT_DIR/final-decision.json"
                '''
            }
        }

        stage('35 - Upload Final Hybrid Decision to AWS S3') {
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

                        echo "[INFO] Uploading final hybrid decision to S3..."

                        aws s3 cp "$ANALYZER_OUTPUT_DIR/final-decision.json" \
                            "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/final-decision.json" \
                            --region "$CLOUD_AWS_REGION"

                        aws s3 cp "$ANALYZER_OUTPUT_DIR/final-decision-report.txt" \
                            "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/final-decision-report.txt" \
                            --region "$CLOUD_AWS_REGION"

                        aws s3 cp "$ANALYZER_OUTPUT_DIR/final-decision.json" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/analyzer/final-decision.json" \
                            --region "$CLOUD_AWS_REGION"

                        aws s3 cp "$ANALYZER_OUTPUT_DIR/final-decision-report.txt" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/analyzer/final-decision-report.txt" \
                            --region "$CLOUD_AWS_REGION"

                        echo "[INFO] Re-syncing full analyzer folder after final decision..."
                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/processed-summaries/${BUILD_LABEL}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$ANALYZER_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/analyzer/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete
                    '''

                    script {
                        env.S3_FINAL_DECISION_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/anomaly-results/${env.BUILD_LABEL}/final-decision.json"
                    }
                }
            }
        }

        stage('36 - Run Safe Remediation Plan') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_SAFE_REMEDIATION
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

                        echo "[INFO] Running safe remediation plan..."

                        . .venv/bin/activate 2>/dev/null || true

                        python cloud/analyzer/remediation/run_safe_remediation.py \
                            --decision "$ANALYZER_OUTPUT_DIR/final-decision.json" \
                            --output-dir "$REMEDIATION_OUTPUT_DIR/plan" \
                            --mode plan \
                            --action "${REMEDIATION_ACTION:-auto}" \
                            --gns3-host "$GNS3_HOST" \
                            --gns3-user "$GNS3_USER" \
                            --gns3-key "$GNS3_KEY"

                        echo "[INFO] Remediation plan:"
                        cat "$REMEDIATION_OUTPUT_DIR/plan/remediation-report.txt" || true
                    '''
                }
            }
        }

        stage('37 - Apply Safe Remediation') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 &&
                           params.ENABLE_SAFE_REMEDIATION &&
                           params.REMEDIATION_MODE == 'apply' &&
                           params.CONFIRM_APPLY
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

                        echo "[INFO] Applying safe remediation..."
                        echo "[INFO] This is allowlisted and requires final-decision.json remediation_allowed=true for infrastructure-changing actions."

                        . .venv/bin/activate 2>/dev/null || true

                        python cloud/analyzer/remediation/run_safe_remediation.py \
                            --decision "$ANALYZER_OUTPUT_DIR/final-decision.json" \
                            --output-dir "$REMEDIATION_OUTPUT_DIR/apply" \
                            --mode apply \
                            --confirm-apply \
                            --action "${REMEDIATION_ACTION:-auto}" \
                            --gns3-host "$GNS3_HOST" \
                            --gns3-user "$GNS3_USER" \
                            --gns3-key "$GNS3_KEY"

                        echo "[INFO] Remediation apply report:"
                        cat "$REMEDIATION_OUTPUT_DIR/apply/remediation-report.txt" || true
                    '''
                }
            }
        }

        stage('38 - Upload Remediation Results to AWS S3') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_SAFE_REMEDIATION
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

                        if [ ! -d "$REMEDIATION_OUTPUT_DIR" ]; then
                            echo "[WARN] No remediation output directory found. Creating empty marker."
                            mkdir -p "$REMEDIATION_OUTPUT_DIR"
                            echo "No remediation output was generated." > "$REMEDIATION_OUTPUT_DIR/README.txt"
                        fi

                        echo "[INFO] Uploading remediation outputs to S3..."

                        aws s3 sync "$REMEDIATION_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/remediation-results/${BUILD_LABEL}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$REMEDIATION_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/anomaly-results/${BUILD_LABEL}/remediation/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete

                        aws s3 sync "$REMEDIATION_OUTPUT_DIR" \
                            "s3://${S3_ARTIFACTS_BUCKET}/latest/remediation/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete
                    '''

                    script {
                        env.S3_REMEDIATION_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/remediation-results/${env.BUILD_LABEL}/"
                    }
                }
            }
        }

        stage('39 - Sync Dashboard Cache from AWS S3') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.PUBLISH_DASHBOARD
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

                        echo "[INFO] Syncing validation/analyzer/metrics cache using existing script..."

                        AWS_REGION="${CLOUD_AWS_REGION}" \
                        ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET}" \
                        ANSIBLE_OUTPUTS_DIR="${DASHBOARD_OUTPUTS_DIR}" \
                        ANALYZER_LATEST_DIR="${DASHBOARD_ANALYZER_DIR}" \
                        METRICS_LATEST_DIR="${DASHBOARD_METRICS_DIR}" \
                        ./cloud/scripts/sync-dashboard-cache-from-s3.sh

                        echo "[INFO] Syncing latest ML outputs to dashboard shared folder..."
                        aws s3 sync "s3://${S3_ARTIFACTS_BUCKET}/latest/ml/" \
                            "${DASHBOARD_ML_DIR}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete || true

                        echo "[INFO] Syncing latest remediation outputs to dashboard shared folder..."
                        aws s3 sync "s3://${S3_ARTIFACTS_BUCKET}/latest/remediation/" \
                            "${DASHBOARD_REMEDIATION_DIR}/" \
                            --region "$CLOUD_AWS_REGION" \
                            --delete || true

                        echo "[INFO] Dashboard shared folder:"
                        find "${DASHBOARD_BASE_DIR}" -maxdepth 5 -type f | sort | sed 's#^# - #' | head -n 160
                    '''
                }
            }
        }

        stage('40 - Show Generated Reports') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        echo "Generated Ansible reports:"
                        ls -lah outputs/
                    '''
                }

                sh '''
                    set -e

                    echo "[INFO] Analyzer output directory:"
                    if [ -d "$ANALYZER_OUTPUT_DIR" ]; then
                        find "$ANALYZER_OUTPUT_DIR" -maxdepth 4 -type f -print | sort
                    else
                        echo "[WARN] Analyzer output directory not found: $ANALYZER_OUTPUT_DIR"
                    fi

                    echo "[INFO] ML output files:"
                    if [ -d "$ML_OUTPUT_DIR" ]; then
                        find "$ML_OUTPUT_DIR" -maxdepth 1 -type f -print | sort
                    else
                        echo "[INFO] No ML outputs directory found."
                    fi

                    echo "[INFO] Dashboard cache:"
                    find "$DASHBOARD_BASE_DIR" -maxdepth 4 -type f | sort | head -n 120 || true
                '''
            }
        }

        stage('41 - Set Jenkins Build Description') {
            steps {
                script {
                    def s3Line = env.S3_ARTIFACTS_URI ? "S3 artifacts: ${env.S3_ARTIFACTS_URI}" : "S3 artifacts: disabled"
                    def analyzerLine = env.S3_ANALYZER_URI ? "Rule analyzer: ${env.S3_ANALYZER_URI}" : "Rule analyzer: disabled"
                    def metricsLine = env.S3_METRICS_URI ? "Metrics snapshot: ${env.S3_METRICS_URI}" : "Metrics snapshot: disabled"
                    def mlLine = env.S3_ML_URI ? "ML decision: ${env.S3_ML_URI}" : "ML decision: disabled"
                    def datasetLine = env.S3_ML_DATASET_URI ? "ML dataset: ${env.S3_ML_DATASET_URI}" : "ML dataset: disabled"
                    def finalDecisionLine = env.S3_FINAL_DECISION_URI ? "Final decision: ${env.S3_FINAL_DECISION_URI}" : "Final decision: disabled"
                    def remediationLine = env.S3_REMEDIATION_URI ? "Remediation: ${env.S3_REMEDIATION_URI}" : "Remediation: disabled"

                    currentBuild.description = """Mode: ${params.PIPELINE_MODE}
Dashboard: ${env.DASHBOARD_URL}
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html
Shared folder: ${env.DASHBOARD_BASE_DIR}
Analyzer cache: ${env.DASHBOARD_ANALYZER_DIR}
Metrics cache: ${env.DASHBOARD_METRICS_DIR}
ML cache: ${env.DASHBOARD_ML_DIR}
Remediation cache: ${env.DASHBOARD_REMEDIATION_DIR}
${s3Line}
${analyzerLine}
${metricsLine}
${mlLine}
${datasetLine}
${finalDecisionLine}
${remediationLine}
"""
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'ansible/outputs/**/*, monitoring/outputs/latest/**/*, cloud/analyzer/outputs/**/*, cloud/analyzer/ml/outputs/**/*, cloud/analyzer/ml/data/features/latest_features.csv', fingerprint: true, allowEmptyArchive: true
        }

        success {
            script {
                def s3Line = env.S3_ARTIFACTS_URI ? "S3 artifacts: ${env.S3_ARTIFACTS_URI}" : "S3 artifacts: disabled"
                def analyzerLine = env.S3_ANALYZER_URI ? "Rule analyzer: ${env.S3_ANALYZER_URI}" : "Rule analyzer: disabled"
                def metricsLine = env.S3_METRICS_URI ? "Metrics snapshot: ${env.S3_METRICS_URI}" : "Metrics snapshot: disabled"
                def mlLine = env.S3_ML_URI ? "ML decision: ${env.S3_ML_URI}" : "ML decision: disabled"
                def finalDecisionLine = env.S3_FINAL_DECISION_URI ? "Final decision: ${env.S3_FINAL_DECISION_URI}" : "Final decision: disabled"
                def remediationLine = env.S3_REMEDIATION_URI ? "Remediation: ${env.S3_REMEDIATION_URI}" : "Remediation: disabled"

                currentBuild.description = """SUCCESS - ${params.PIPELINE_MODE}
Dashboard: ${env.DASHBOARD_URL}
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html
Shared folder: ${env.DASHBOARD_BASE_DIR}
${s3Line}
${analyzerLine}
${metricsLine}
${mlLine}
${finalDecisionLine}
${remediationLine}
"""
            }

            echo 'PFE local automation, ML analysis and safe remediation pipeline completed successfully.'
        }

        failure {
            script {
                def s3Line = env.S3_ARTIFACTS_URI ? "S3 artifacts: ${env.S3_ARTIFACTS_URI}" : "S3 artifacts: not uploaded"
                def analyzerLine = env.S3_ANALYZER_URI ? "Rule analyzer: ${env.S3_ANALYZER_URI}" : "Rule analyzer: not uploaded"
                def metricsLine = env.S3_METRICS_URI ? "Metrics snapshot: ${env.S3_METRICS_URI}" : "Metrics snapshot: not uploaded"
                def mlLine = env.S3_ML_URI ? "ML decision: ${env.S3_ML_URI}" : "ML decision: not generated"
                def finalDecisionLine = env.S3_FINAL_DECISION_URI ? "Final decision: ${env.S3_FINAL_DECISION_URI}" : "Final decision: not generated"
                def remediationLine = env.S3_REMEDIATION_URI ? "Remediation: ${env.S3_REMEDIATION_URI}" : "Remediation: not generated"

                currentBuild.description = """FAILED - ${params.PIPELINE_MODE}
Check console output and archived artifacts.
HTML summary if generated: ${env.BUILD_URL}artifact/ansible/outputs/index.html
${s3Line}
${analyzerLine}
${metricsLine}
${mlLine}
${finalDecisionLine}
${remediationLine}
"""
            }

            echo 'PFE local automation pipeline failed. Check Jenkins console output and archived reports.'
        }
    }
}