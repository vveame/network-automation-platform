pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        DASHBOARD_OUTPUTS_DIR = '/var/lib/pfe-dashboard/outputs'
        DASHBOARD_URL = 'http://10.200.0.10:5050'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                deleteDir()
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Show Environment') {
            steps {
                sh '''
                    echo "Workspace: $WORKSPACE"
                    whoami
                    hostname
                    pwd
                    git --version
                    ansible --version
                    ansible-playbook --version
                '''
            }
        }

        stage('Prepare Outputs Directory') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        rm -rf outputs
                        mkdir -p outputs
                    '''
                }
            }
        }

        stage('Inventory Check') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        ansible-inventory --graph
                        ansible-inventory --list > outputs/jenkins-inventory.json
                    '''
                }
            }
        }

        stage('Syntax Check') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        ansible-playbook --syntax-check playbooks/site.yml
                    '''
                }
            }
        }

        stage('Run Ansible Validation Gate') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    withCredentials([
                        sshUserPrivateKey(
                            credentialsId: 'pfe-oob-root-key',
                            keyFileVariable: 'PFE_SSH_KEY',
                            usernameVariable: 'PFE_SSH_USER'
                        )
                    ]) {
                        sh '''
                            ansible-playbook playbooks/site.yml \
                              -e "ansible_user=${PFE_SSH_USER} ansible_ssh_private_key_file=${PFE_SSH_KEY}"
                        '''
                    }
                }
            }
        }

        stage('Generate HTML Summary') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        python3 - <<'PY'
from pathlib import Path
from html import escape
from datetime import datetime

outputs = Path("outputs")
html_file = outputs / "index.html"

reports = sorted(outputs.glob("*.txt"))
passed = []
failed = []
missing = []

critical_patterns = ["FAILED!", "fatal:", "UNREACHABLE!", "ERROR!", "Traceback"]

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
    body {{
      font-family: Arial, sans-serif;
      background: #f8fafc;
      color: #0f172a;
      margin: 0;
      padding: 32px;
    }}
    .hero {{
      background: white;
      border-radius: 18px;
      padding: 24px;
      box-shadow: 0 10px 25px rgba(15, 23, 42, 0.08);
      margin-bottom: 24px;
    }}
    h1 {{
      margin: 0 0 8px 0;
    }}
    .status {{
      display: inline-block;
      padding: 8px 14px;
      border-radius: 999px;
      font-weight: bold;
      background: {"#dcfce7" if status == "PASSED" else "#fee2e2"};
      color: {"#166534" if status == "PASSED" else "#991b1b"};
    }}
    .cards {{
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 16px;
      margin-bottom: 24px;
    }}
    .card {{
      background: white;
      border-radius: 16px;
      padding: 18px;
      box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
    }}
    .card span {{
      color: #64748b;
      font-size: 13px;
    }}
    .card strong {{
      display: block;
      font-size: 28px;
      margin-top: 8px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      background: white;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
    }}
    th, td {{
      padding: 14px;
      border-bottom: 1px solid #e2e8f0;
      vertical-align: top;
      text-align: left;
    }}
    th {{
      background: #e2e8f0;
    }}
    .passed {{
      color: #166534;
      font-weight: bold;
    }}
    .failed {{
      color: #991b1b;
      font-weight: bold;
    }}
    .missing {{
      color: #92400e;
      font-weight: bold;
    }}
    pre {{
      white-space: pre-wrap;
      max-height: 220px;
      overflow: auto;
      background: #f1f5f9;
      padding: 12px;
      border-radius: 12px;
      margin: 0;
    }}
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
    <thead>
      <tr>
        <th>Report</th>
        <th>Status</th>
        <th>Size</th>
        <th>Preview</th>
      </tr>
    </thead>
    <tbody>
      {''.join(rows)}
    </tbody>
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

        stage('Sync Latest Reports For Dashboard') {
            steps {
                sh '''
                    mkdir -p "$DASHBOARD_OUTPUTS_DIR"
                    rsync -a --delete ansible/outputs/ "$DASHBOARD_OUTPUTS_DIR/"
                    echo "Latest reports copied to $DASHBOARD_OUTPUTS_DIR"
                    ls -lah "$DASHBOARD_OUTPUTS_DIR"
                '''
            }
        }

        stage('Show Generated Reports') {
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        echo "Generated reports:"
                        ls -lah outputs/
                    '''
                }
            }
        }

        stage('Set Build Description') {
            steps {
                script {
                    currentBuild.description = """PFE network validation passed.
Dashboard: ${env.DASHBOARD_URL}
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html
Reports folder: ${env.DASHBOARD_OUTPUTS_DIR}
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
                currentBuild.description = """SUCCESS - PFE network validation passed.
Dashboard: ${env.DASHBOARD_URL}
HTML summary: ${env.BUILD_URL}artifact/ansible/outputs/index.html
Reports folder: ${env.DASHBOARD_OUTPUTS_DIR}
"""
            }
            echo 'PFE network validation pipeline completed successfully.'
        }

        failure {
            script {
                currentBuild.description = """FAILED - PFE network validation failed.
Check console output and archived artifacts.
HTML summary if generated: ${env.BUILD_URL}artifact/ansible/outputs/index.html
"""
            }
            echo 'PFE network validation pipeline failed. Check Ansible logs and archived reports.'
        }
    }
}