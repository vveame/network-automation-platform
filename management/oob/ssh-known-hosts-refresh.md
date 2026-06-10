# Refreshing SSH Known Hosts After GNS3 Container Recreation

This note documents a recurring operational issue in the PFE GNS3 lab.

When GNS3 Docker containers are recreated, their SSH host keys can change. The DevOps VM may then show the following warning when connecting to a node over the OOB management network:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Host key verification failed.
```

In a real production environment, this warning must be investigated carefully because it may indicate a man-in-the-middle attack.

In this lab, the warning is commonly a false positive after a controlled Docker image rebuild, container recreation or persistent topology refresh. The recreated container presents a new SSH host key while keeping the same OOB management IP address.

## Affected OOB Nodes

The known OOB-managed GNS3 nodes are:

| Node                  | OOB IP        |
| --------------------- | ------------- |
| Core-FRR-1            | `10.200.0.11` |
| Core-FRR-2            | `10.200.0.12` |
| Dist-FRR-1            | `10.200.0.21` |
| Dist-FRR-2            | `10.200.0.22` |
| EdgeRouter-VPNGateway | `10.200.0.30` |
| Dist-OVS-1            | `10.200.0.31` |
| Dist-OVS-2            | `10.200.0.32` |
| DMZ-OVS-3             | `10.200.0.33` |
| Access-OVS-4          | `10.200.0.44` |
| Access-OVS-5          | `10.200.0.45` |
| Access-OVS-6          | `10.200.0.46` |

## Manual Fix for One Node

Example for EdgeRouter-VPNGateway:

```bash
ssh-keygen -f ~/.ssh/known_hosts -R 10.200.0.30
ssh-keyscan -H -t ed25519,ecdsa,rsa 10.200.0.30 >> ~/.ssh/known_hosts
```

Then test:

```bash
ssh root@10.200.0.30 hostname
```

## Security Rule

Do not globally disable SSH host key checking.

Avoid using:

```text
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
```

as a permanent solution.

The platform keeps SSH host key verification enabled and refreshes known hosts only after controlled container recreation.

## Why This Matters

This keeps the DevOps automation workflow reliable after GNS3 container recreation while preserving SSH security behavior.

It also avoids confusing normal lab rebuild behavior with real man-in-the-middle warnings.
