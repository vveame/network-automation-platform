pipeline {
    agent any

    /*
     * PFE Hybrid Automation Pipeline
     *
     * Final architecture:
     * - Jenkins stays on the local DevOps VM.
     * - Local validation and safe remediation stay on the DevOps/GNS3 side.
     * - Monitoring snapshot, rule-based analyzer, ML analyzer and final decision run on AWS monitoring EC2.
     * - S3 is the shared storage/source of truth between DevOps and AWS.
     */

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 90, unit: 'MINUTES')
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
            description: 'Required only for GNS3 apply/refresh actions or remediation apply mode.'
        )

        booleanParam(
            name: 'AUTO_PUSH_IMAGES',
            defaultValue: true,
            description: 'In AUTO mode, push changed Docker images to Docker Hub after successful build.'
        )

        string(
            name: 'DOCKERHUB_NAMESPACE',
            defaultValue: 'vviam',
            description: 'Docker Hub namespace/user where images are pushed.'
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
            description: 'Enable final hybrid flow: upload validation to S3, trigger AWS monitoring/AI, fetch decision, and publish dashboard cache.'
        )

        string(
            name: 'S3_ARTIFACTS_BUCKET',
            defaultValue: 'CHANGE_ME',
            description: 'Terraform-created S3 artifacts bucket. Keep CHANGE_ME in public repo and pass real value from Jenkins/local trigger.'
        )

        string(
            name: 'CLOUD_AWS_REGION',
            defaultValue: 'eu-north-1',
            description: 'AWS region used for S3 artifact exchange.'
        )

        choice(
            name: 'HYBRID_EXECUTION_MODE',
            choices: [ 'AWS_MONITORING_AI' ],
            description: 'Final hybrid mode: monitoring, rule analyzer and ML run in AWS; Jenkins/remediation stay on DevOps VM.'
        )

        string(
            name: 'AWS_MONITORING_HOST',
            defaultValue: 'CHANGE_ME',
            description: 'Private IP or reachable hostname of the AWS monitoring EC2 instance.'
        )

        string(
            name: 'AWS_MONITORING_USER',
            defaultValue: 'ec2-user',
            description: 'SSH user for the AWS monitoring EC2 instance.'
        )

        string(
            name: 'AWS_REMOTE_REPO_DIR',
            defaultValue: '/home/ec2-user/pfe-cloud-runtime',
            description: 'Remote runtime directory on the AWS monitoring EC2.'
        )

        string(
            name: 'CLOUD_PROMETHEUS_URL',
            defaultValue: 'http://localhost:9090',
            description: 'Prometheus URL as seen from the AWS monitoring EC2.'
        )

        string(
            name: 'ML_FEATURES_FILE',
            defaultValue: 'cloud/analyzer/ml/features.cloud.json',
            description: 'Cloud ML feature profile used on the AWS monitoring EC2.'
        )

        booleanParam(
            name: 'ENABLE_ML_ANALYZER',
            defaultValue: true,
            description: 'Run the ML Isolation Forest analyzer inside the AWS monitoring environment.'
        )

        booleanParam(
            name: 'TRAIN_ML_MODEL',
            defaultValue: false,
            description: 'Retrain the Isolation Forest model during this build. If false, AWS reuses/trains only when model is missing.'
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
            description: 'Generate a local safe remediation plan after the cloud final decision is fetched.'
        )

        choice(
            name: 'REMEDIATION_MODE',
            choices: [ 'plan', 'apply' ],
            description: 'plan does not execute changes. apply executes allowlisted changes and requires CONFIRM_APPLY.'
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
                    env.BUILD_LABEL = "${env.JOB_NAME}-${env.BUILD_NUMBER}".replaceAll('[^A-Za-z0-9_.-]', '-')
                    env.ANALYZER_OUTPUT_DIR = "cloud/analyzer/outputs/${env.BUILD_LABEL}"
                    env.REMEDIATION_OUTPUT_DIR = "${env.ANALYZER_OUTPUT_DIR}/remediation"

                    env.S3_ARTIFACTS_URI = ''
                    env.S3_METRICS_URI = ''
                    env.S3_ANALYZER_URI = ''
                    env.S3_ML_URI = ''
                    env.S3_ML_DATASET_URI = ''
                    env.S3_FINAL_DECISION_URI = ''
                    env.S3_REMEDIATION_URI = ''
                }
            }
        }

        stage('04 - Show Execution Environment') {
            steps {
                sh '''
                    set -e
                    echo "Workspace: $WORKSPACE"
                    echo "User: $(whoami)"
                    echo "Host: $(hostname)"
                    echo "Build label: ${BUILD_LABEL}"
                    echo "Pipeline mode: ${PIPELINE_MODE}"
                    echo "Hybrid execution mode: ${HYBRID_EXECUTION_MODE}"
                    echo "Docker namespace: ${DOCKERHUB_NAMESPACE}"
                    echo "Image tag: ${IMAGE_TAG}"
                    echo "Export artifacts to S3: ${EXPORT_ARTIFACTS_TO_S3}"
                    echo "S3 bucket: ${S3_ARTIFACTS_BUCKET}"
                    echo "AWS region: ${CLOUD_AWS_REGION}"
                    echo "AWS monitoring host: ${AWS_MONITORING_HOST}"
                    echo "AWS remote repo dir: ${AWS_REMOTE_REPO_DIR}"
                    echo "Cloud Prometheus URL from AWS EC2: ${CLOUD_PROMETHEUS_URL}"
                    echo "ML analyzer enabled: ${ENABLE_ML_ANALYZER}"
                    echo "ML features file: ${ML_FEATURES_FILE}"
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
                    env.CHANGED_MONITORING = changedFiles.contains('monitoring/') || changedFiles.contains('cloud/monitoring/') ? 'true' : 'false'

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
                        (params.PIPELINE_MODE == 'AUTO' && env.CHANGED_DOCKER_ANY == 'true') ||
                        (params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_SAFE_REMEDIATION)
                    )
                }
            }
            steps {
                sh '''
                    set -e
                    if [ "$GNS3_HOST" = "CHANGE_ME" ] || [ -z "$GNS3_HOST" ]; then
                        echo "[ERROR] GNS3_HOST must be set for Docker/GNS3/remediation stages."
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

        stage('09 - Prepare Shared Dashboard Folders') {
            steps {
                sh '''
                    set -e
                    mkdir -p "${DASHBOARD_OUTPUTS_DIR}" \
                             "${DASHBOARD_ANALYZER_DIR}" \
                             "${DASHBOARD_METRICS_DIR}" \
                             "${DASHBOARD_ML_DIR}" \
                             "${DASHBOARD_REMEDIATION_DIR}"

                    if [ ! -w "${DASHBOARD_BASE_DIR}" ]; then
                        echo "[ERROR] Jenkins cannot write to ${DASHBOARD_BASE_DIR}"
                        echo "[INFO] Fix on DevOps VM: sudo mkdir -p ${DASHBOARD_BASE_DIR} && sudo chown -R jenkins:jenkins ${DASHBOARD_BASE_DIR}"
                        exit 1
                    fi
                    echo "[OK] Shared dashboard folder ready: ${DASHBOARD_BASE_DIR}"
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
                                find . -type f | while IFS= read -r f; do
                                    case "$f" in
                                        *.env|*/.env|*.secret)
                                            cp --parents "$f" "$LOCAL_FILES_DIR" || true
                                            ;;
                                    esac
                                done
                            fi

                            if [ ! -d "$REPO_DIR/.git" ]; then
                                echo "[WARN] $REPO_DIR is not a valid git repo. Re-cloning."
                                if [ -d "$REPO_DIR" ]; then
                                    BACKUP_DIR="${REPO_DIR}.backup.$(date +%Y%m%d%H%M%S)"
                                    mv "$REPO_DIR" "$BACKUP_DIR"
                                fi
                                git clone "$REPO_URL" "$REPO_DIR"
                            fi

                            cd "$REPO_DIR"
                            git remote remove origin 2>/dev/null || true
                            git remote add origin "$REPO_URL"
                            git fetch --prune origin main
                            git checkout -f -B main origin/main
                            git reset --hard origin/main
                            git clean -fd

                            echo "[INFO] Restoring local env/secret files..."
                            if [ -d "$LOCAL_FILES_DIR" ]; then
                                cp -a "$LOCAL_FILES_DIR"/. "$REPO_DIR"/ || true
                            fi

                            echo "[OK] GNS3 host repository synced."
                            git status --short
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
                    sh '''
                        set -e
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                          "cd /home/gns3/pfe-repo && docker build --network=host -t ${DOCKERHUB_NAMESPACE}/${FRR_IMAGE}:${IMAGE_TAG} docker/frr-ssh"
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
                    sh '''
                        set -e
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                          "cd /home/gns3/pfe-repo && docker build --network=host -t ${DOCKERHUB_NAMESPACE}/${OVS_IMAGE}:${IMAGE_TAG} docker/ovs-ssh"
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
                    sh '''
                        set -e
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                          "cd /home/gns3/pfe-repo && docker build --network=host -f docker/web-nginx/Dockerfile -t ${DOCKERHUB_NAMESPACE}/${WEB_IMAGE}:${IMAGE_TAG} ."
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
                    sh '''
                        set -e
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" \
                          "cd /home/gns3/pfe-repo && docker build --network=host -f docker/dns/Dockerfile -t ${DOCKERHUB_NAMESPACE}/${DNS_IMAGE}:${IMAGE_TAG} ."
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
                    sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER'),
                    usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN')
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
                    sh '''
                        set -e
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" '
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
                withCredentials([sshUserPrivateKey(credentialsId: 'gns3-host-ssh-key', keyFileVariable: 'GNS3_KEY', usernameVariable: 'GNS3_USER')]) {
                    sh '''
                        set -e
                        ssh -i "$GNS3_KEY" -o StrictHostKeyChecking=no "$GNS3_USER@$GNS3_HOST" '
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
                            set -e
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
                        set -e
                        python3 ../scripts/jenkins/generate-html-summary.py outputs
                    '''
                }
            }
        }

        stage('21 - Validate Generated Dashboard Reports') {
            steps {
                sh '''
                    set -e
                    echo "[INFO] Validating generated report files in Jenkins workspace..."
                    test -d ansible/outputs
                    test -n "$(ls -A ansible/outputs 2>/dev/null)"
                    test -f ansible/outputs/validation-summary.txt
                    echo "[OK] Jenkins workspace validation reports are ready."
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

        stage('23 - Guard AWS Hybrid Monitoring and AI Inputs') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                sh '''
                    set -e
                    if [ "$S3_ARTIFACTS_BUCKET" = "CHANGE_ME" ] || [ -z "$S3_ARTIFACTS_BUCKET" ]; then
                        echo "[ERROR] S3_ARTIFACTS_BUCKET must be set."
                        exit 1
                    fi
                    if [ "$AWS_MONITORING_HOST" = "CHANGE_ME" ] || [ -z "$AWS_MONITORING_HOST" ]; then
                        echo "[ERROR] AWS_MONITORING_HOST must be set to the AWS monitoring EC2 private IP or reachable hostname."
                        exit 1
                    fi
                    if [ ! -f "cloud/scripts/run-cloud-monitoring-ai-cycle.sh" ]; then
                        echo "[ERROR] Missing cloud/scripts/run-cloud-monitoring-ai-cycle.sh"
                        echo "[INFO] Create this script before running the final hybrid pipeline."
                        exit 1
                    fi
                    if [ ! -f "$ML_FEATURES_FILE" ]; then
                        echo "[ERROR] Missing ML feature profile: $ML_FEATURES_FILE"
                        exit 1
                    fi
                    if ! command -v tar >/dev/null 2>&1; then
                        echo "[ERROR] tar is required on Jenkins."
                        exit 1
                    fi
                    echo "[OK] AWS hybrid inputs validated."
                    echo "AWS monitoring host: $AWS_MONITORING_HOST"
                    echo "AWS remote repo dir: $AWS_REMOTE_REPO_DIR"
                    echo "Cloud Prometheus URL: $CLOUD_PROMETHEUS_URL"
                    echo "ML features file: $ML_FEATURES_FILE"
                '''
            }
        }

        stage('24 - Sync Cloud Monitoring and AI Runtime to AWS EC2') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'aws-monitoring-ssh-key',
                    keyFileVariable: 'AWS_MONITORING_KEY',
                    usernameVariable: 'AWS_MONITORING_CRED_USER'
                )]) {
                    sh '''
                        set -e
                        SSH_USER="${AWS_MONITORING_USER:-$AWS_MONITORING_CRED_USER}"

                        echo "[INFO] Checking AWS monitoring EC2 SSH access..."
                        ssh -i "$AWS_MONITORING_KEY" \
                          -o BatchMode=yes \
                          -o StrictHostKeyChecking=no \
                          -o ConnectTimeout=15 \
                          "$SSH_USER@$AWS_MONITORING_HOST" \
                          "hostname && whoami && python3 --version && command -v aws && command -v curl && command -v tar"

                        echo "[INFO] Syncing cloud analyzer/runtime code to AWS monitoring EC2..."
                        tar czf - \
                          cloud/analyzer \
                          cloud/scripts \
                          cloud/monitoring \
                          monitoring/scripts \
                          monitoring/grafana \
                          | ssh -i "$AWS_MONITORING_KEY" \
                              -o BatchMode=yes \
                              -o StrictHostKeyChecking=no \
                              -o ConnectTimeout=15 \
                              "$SSH_USER@$AWS_MONITORING_HOST" \
                              "mkdir -p '$AWS_REMOTE_REPO_DIR' && tar xzf - -C '$AWS_REMOTE_REPO_DIR'"

                        ssh -i "$AWS_MONITORING_KEY" \
                          -o BatchMode=yes \
                          -o StrictHostKeyChecking=no \
                          -o ConnectTimeout=15 \
                          "$SSH_USER@$AWS_MONITORING_HOST" \
                          "cd '$AWS_REMOTE_REPO_DIR' && chmod +x cloud/scripts/run-cloud-monitoring-ai-cycle.sh && test -f '$ML_FEATURES_FILE' && echo '[OK] AWS runtime synced.'"
                    '''
                }
            }
        }

        stage('25 - Run Cloud Monitoring Snapshot Analyzer and ML on AWS EC2') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3
                }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'aws-monitoring-ssh-key',
                        keyFileVariable: 'AWS_MONITORING_KEY',
                        usernameVariable: 'AWS_MONITORING_CRED_USER'
                    ),
                    usernamePassword(
                        credentialsId: 'aws-pfe-artifacts-creds',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -e
                        SSH_USER="${AWS_MONITORING_USER:-$AWS_MONITORING_CRED_USER}"
                        REMOTE_ENV_FILE="/tmp/pfe-cloud-ai-env-${BUILD_LABEL}.sh"
                        LOCAL_ENV_FILE="$(mktemp)"
                        trap 'rm -f "$LOCAL_ENV_FILE"' EXIT

                        AWS_ACCESS_KEY_ID_B64="$(printf '%s' "$AWS_ACCESS_KEY_ID" | base64 -w0)"
                        AWS_SECRET_ACCESS_KEY_B64="$(printf '%s' "$AWS_SECRET_ACCESS_KEY" | base64 -w0)"

                        cat > "$LOCAL_ENV_FILE" <<EOF_REMOTE_ENV
export AWS_ACCESS_KEY_ID_B64='$AWS_ACCESS_KEY_ID_B64'
export AWS_SECRET_ACCESS_KEY_B64='$AWS_SECRET_ACCESS_KEY_B64'
export AWS_REGION='$CLOUD_AWS_REGION'
export AWS_DEFAULT_REGION='$CLOUD_AWS_REGION'
export ARTIFACTS_BUCKET='$S3_ARTIFACTS_BUCKET'
export BUILD_TAG='$BUILD_LABEL'
export PROMETHEUS_URL='$CLOUD_PROMETHEUS_URL'
export ENABLE_ML_ANALYZER='$ENABLE_ML_ANALYZER'
export TRAIN_ML_MODEL='$TRAIN_ML_MODEL'
export ML_DURATION_MINUTES='$ML_DURATION_MINUTES'
export ML_STEP='$ML_STEP'
export ML_CONTAMINATION='$ML_CONTAMINATION'
export ML_FEATURES_FILE='$ML_FEATURES_FILE'
EOF_REMOTE_ENV

                        scp -i "$AWS_MONITORING_KEY" \
                          -o BatchMode=yes \
                          -o StrictHostKeyChecking=no \
                          -o ConnectTimeout=15 \
                          "$LOCAL_ENV_FILE" \
                          "$SSH_USER@$AWS_MONITORING_HOST:$REMOTE_ENV_FILE"

                        echo "[INFO] Triggering AWS monitoring/AI cycle remotely..."
                        ssh -i "$AWS_MONITORING_KEY" \
                          -o BatchMode=yes \
                          -o StrictHostKeyChecking=no \
                          -o ConnectTimeout=15 \
                          "$SSH_USER@$AWS_MONITORING_HOST" \
                          "set -e
                           chmod 600 '$REMOTE_ENV_FILE'
                           . '$REMOTE_ENV_FILE'
                           export AWS_ACCESS_KEY_ID=\$(printf '%s' \"\$AWS_ACCESS_KEY_ID_B64\" | base64 -d)
                           export AWS_SECRET_ACCESS_KEY=\$(printf '%s' \"\$AWS_SECRET_ACCESS_KEY_B64\" | base64 -d)
                           rm -f '$REMOTE_ENV_FILE'
                           cd '$AWS_REMOTE_REPO_DIR'
                           ./cloud/scripts/run-cloud-monitoring-ai-cycle.sh"
                    '''
                    script {
                        env.S3_METRICS_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/metrics-snapshots/${env.BUILD_LABEL}/"
                        env.S3_ANALYZER_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/anomaly-results/${env.BUILD_LABEL}/"
                        env.S3_ML_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/ml-results/${env.BUILD_LABEL}/"
                        env.S3_ML_DATASET_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/ml-datasets/${env.BUILD_LABEL}/latest_features.csv"
                        env.S3_FINAL_DECISION_URI = "s3://${params.S3_ARTIFACTS_BUCKET}/latest/analyzer/final-decision.json"
                    }
                }
            }
        }

        stage('26 - Fetch AWS Final Decision for Local Remediation') {
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
                        echo "[INFO] Fetching cloud-generated analyzer/final decision back to Jenkins workspace..."
                        mkdir -p "$ANALYZER_OUTPUT_DIR"
                        aws s3 sync \
                          "s3://${S3_ARTIFACTS_BUCKET}/latest/analyzer/" \
                          "$ANALYZER_OUTPUT_DIR/" \
                          --region "$CLOUD_AWS_REGION" \
                          --delete

                        test -f "$ANALYZER_OUTPUT_DIR/final-decision.json"
                        test -f "$ANALYZER_OUTPUT_DIR/decision.json"

                        echo "[INFO] Final decision fetched for local remediation:"
                        python3 -m json.tool "$ANALYZER_OUTPUT_DIR/final-decision.json" || cat "$ANALYZER_OUTPUT_DIR/final-decision.json"
                    '''
                }
            }
        }

        stage('27 - Run Safe Remediation Plan Locally') {
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
                        echo "[INFO] Running local safe remediation plan on DevOps VM..."
                        mkdir -p "$REMEDIATION_OUTPUT_DIR/plan"
                        if [ -f .venv/bin/activate ]; then . .venv/bin/activate; fi
                        python3 cloud/analyzer/remediation/run_safe_remediation.py \
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

        stage('28 - Apply Safe Remediation Locally') {
            when {
                expression {
                    return params.EXPORT_ARTIFACTS_TO_S3 && params.ENABLE_SAFE_REMEDIATION && params.REMEDIATION_MODE == 'apply' && params.CONFIRM_APPLY
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
                        echo "[INFO] Applying safe remediation locally from DevOps VM..."
                        echo "[INFO] This is allowlisted and requires final-decision.json remediation_allowed=true."
                        mkdir -p "$REMEDIATION_OUTPUT_DIR/apply"
                        if [ -f .venv/bin/activate ]; then . .venv/bin/activate; fi
                        python3 cloud/analyzer/remediation/run_safe_remediation.py \
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

        stage('29 - Upload Remediation Results to AWS S3') {
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

                        echo "[INFO] Uploading local remediation outputs to S3..."
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

        stage('30 - Sync Dashboard Cache from AWS S3') {
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
                        chmod +x cloud/scripts/sync-dashboard-cache-from-s3.sh
                        echo "[INFO] Syncing validation/analyzer/metrics cache from S3..."
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

        stage('31 - Show Generated Reports') {
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
                        find "$ANALYZER_OUTPUT_DIR" -maxdepth 5 -type f -print | sort
                    else
                        echo "[WARN] Analyzer output directory not found: $ANALYZER_OUTPUT_DIR"
                    fi

                    echo "[INFO] Dashboard cache:"
                    find "$DASHBOARD_BASE_DIR" -maxdepth 4 -type f | sort | head -n 120 || true
                '''
            }
        }

        stage('32 - Set Jenkins Build Description') {
            steps {
                script {
                    def s3Line = env.S3_ARTIFACTS_URI ? "S3 validation: ${env.S3_ARTIFACTS_URI}" : "S3 validation: disabled"
                    def analyzerLine = env.S3_ANALYZER_URI ? "AWS analyzer: ${env.S3_ANALYZER_URI}" : "AWS analyzer: disabled"
                    def metricsLine = env.S3_METRICS_URI ? "AWS metrics: ${env.S3_METRICS_URI}" : "AWS metrics: disabled"
                    def mlLine = env.S3_ML_URI ? "AWS ML: ${env.S3_ML_URI}" : "AWS ML: disabled"
                    def datasetLine = env.S3_ML_DATASET_URI ? "ML dataset: ${env.S3_ML_DATASET_URI}" : "ML dataset: disabled"
                    def finalDecisionLine = env.S3_FINAL_DECISION_URI ? "Final decision: ${env.S3_FINAL_DECISION_URI}" : "Final decision: disabled"
                    def remediationLine = env.S3_REMEDIATION_URI ? "Local remediation: ${env.S3_REMEDIATION_URI}" : "Local remediation: disabled"

                    currentBuild.description = """
Mode: ${params.PIPELINE_MODE}<br/>
Hybrid: AWS monitoring/AI + local Jenkins/remediation<br/>
Dashboard: ${env.DASHBOARD_URL}<br/>
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html<br/>
Shared folder: ${env.DASHBOARD_BASE_DIR}<br/>
Analyzer cache: ${env.DASHBOARD_ANALYZER_DIR}<br/>
Metrics cache: ${env.DASHBOARD_METRICS_DIR}<br/>
ML cache: ${env.DASHBOARD_ML_DIR}<br/>
Remediation cache: ${env.DASHBOARD_REMEDIATION_DIR}<br/>
${s3Line}<br/>
${analyzerLine}<br/>
${metricsLine}<br/>
${mlLine}<br/>
${datasetLine}<br/>
${finalDecisionLine}<br/>
${remediationLine}
"""
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts(
                artifacts: 'ansible/outputs/**/*, cloud/analyzer/outputs/**/*',
                fingerprint: true,
                allowEmptyArchive: true
            )
        }

        success {
            script {
                def s3Line = env.S3_ARTIFACTS_URI ? "S3 validation: ${env.S3_ARTIFACTS_URI}" : "S3 validation: disabled"
                def analyzerLine = env.S3_ANALYZER_URI ? "AWS analyzer: ${env.S3_ANALYZER_URI}" : "AWS analyzer: disabled"
                def metricsLine = env.S3_METRICS_URI ? "AWS metrics: ${env.S3_METRICS_URI}" : "AWS metrics: disabled"
                def mlLine = env.S3_ML_URI ? "AWS ML: ${env.S3_ML_URI}" : "AWS ML: disabled"
                def finalDecisionLine = env.S3_FINAL_DECISION_URI ? "Final decision: ${env.S3_FINAL_DECISION_URI}" : "Final decision: disabled"
                def remediationLine = env.S3_REMEDIATION_URI ? "Local remediation: ${env.S3_REMEDIATION_URI}" : "Local remediation: disabled"

                currentBuild.description = """
SUCCESS - ${params.PIPELINE_MODE}<br/>
Hybrid: AWS monitoring/AI + local Jenkins/remediation<br/>
Dashboard: ${env.DASHBOARD_URL}<br/>
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html<br/>
Shared folder: ${env.DASHBOARD_BASE_DIR}<br/>
${s3Line}<br/>
${analyzerLine}<br/>
${metricsLine}<br/>
${mlLine}<br/>
${finalDecisionLine}<br/>
${remediationLine}
"""
            }
            echo 'PFE final hybrid automation pipeline completed successfully.'
        }

        failure {
            script {
                def s3Line = env.S3_ARTIFACTS_URI ? "S3 validation: ${env.S3_ARTIFACTS_URI}" : "S3 validation: not uploaded"
                def analyzerLine = env.S3_ANALYZER_URI ? "AWS analyzer: ${env.S3_ANALYZER_URI}" : "AWS analyzer: not completed"
                def metricsLine = env.S3_METRICS_URI ? "AWS metrics: ${env.S3_METRICS_URI}" : "AWS metrics: not completed"
                def mlLine = env.S3_ML_URI ? "AWS ML: ${env.S3_ML_URI}" : "AWS ML: not completed"
                def finalDecisionLine = env.S3_FINAL_DECISION_URI ? "Final decision: ${env.S3_FINAL_DECISION_URI}" : "Final decision: not generated"
                def remediationLine = env.S3_REMEDIATION_URI ? "Local remediation: ${env.S3_REMEDIATION_URI}" : "Local remediation: not completed"

                currentBuild.description = """
FAILED - ${params.PIPELINE_MODE}<br/>
Check console output and archived artifacts.<br/>
${s3Line}<br/>
${analyzerLine}<br/>
${metricsLine}<br/>
${mlLine}<br/>
${finalDecisionLine}<br/>
${remediationLine}
"""
            }
            echo 'PFE final hybrid pipeline failed. Check console output and archived artifacts.'
        }
    }
}
