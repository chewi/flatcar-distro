#!/bin/bash

set -euo pipefail

rootfs="${1}"

mkdir -p "${rootfs}/usr/lib/systemd/system/amazon-ssm-agent.service.d"
cat > "${rootfs}/usr/lib/systemd/system/amazon-ssm-agent.service.d/10-bindpaths.conf" <<-'EOF'
[Service]
BindPaths=/usr/share/amazon/ssm/:/etc/amazon/ssm/ /usr/share/amazon/eks/boostrap.sh:/etc/eks/bootstrap.sh
EOF

mkdir -p "${rootfs}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=amazon-ssm-agent.service coreos-metadata-sshkeys@core.service setup-oem.service"; } > "${rootfs}/usr/lib/systemd/system/multi-user.target.d/10-oem-ec2.conf"
