#!/bin/bash

set -euo pipefail

rootfs="${1}"

to_delete=(
  /etc/systemd/system/amazon-ssm-agent.service
  /etc/systemd/system/multi-user.target.requires/coreos-metadata-sshkeys@core.service
  /etc/amazon/ssm/
  /etc/eks/bootstrap.sh
)

rm -rf "${to_delete[@]/#/${rootfs}}"

cat > "${rootfs}/usr/lib/systemd/system/setup-oem.service" <<-'EOF'
[Unit]
Description=Setup OEM
Before=amazon-ssm-agent.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/mkdir --parents /etc/amazon/ssm/ /etc/eks
ExecStartPre=-/usr/bin/ln --symbolic /usr/share/amazon/ssm/amazon-ssm-agent.json.template /etc/amazon/ssm/amazon-ssm-agent.json
ExecStartPre=-/usr/bin/ln --symbolic /usr/share/amazon/ssm/seelog.xml.template /etc/amazon/ssm/seelog.xml
ExecStart=-/usr/bin/ln --symbolic /usr/share/amazon/eks/bootstrap.sh /etc/eks/bootstrap.sh
[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${rootfs}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=amazon-ssm-agent.service"; } > "${rootfs}/usr/lib/systemd/system/multi-user.target.d/10-oem-ec2.conf"
