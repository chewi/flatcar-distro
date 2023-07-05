# Copyright (c) 2014 CoreOS, Inc.. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="OEM suite for VMware"
HOMEPAGE="https://www.vmware.com/"
SRC_URI=""

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64 arm64"
IUSE=""

RDEPEND="
	~app-emulation/open-vm-tools-${PV}
	"

# no source directory
S="${WORKDIR}"

# for coreos-base/common-oem-files
OEM_NAME="VMware"

src_install() {
	systemd_dounit "${FILESDIR}/units/vmtoolsd.service"
}
