# Copyright 2007-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools linux-info pam systemd udev

DESCRIPTION="Tools for VMware guests"
HOMEPAGE="https://github.com/vmware/open-vm-tools"
MY_P="${P}-21855600"
SRC_URI="https://github.com/vmware/open-vm-tools/releases/download/stable-${PV}/${MY_P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="X +deploypkg +dnet doc +fuse gtkmm +icu multimon pam +resolutionkms +ssl +vgauth"
REQUIRED_USE="
	multimon? ( X )
	vgauth? ( ssl )
"

RDEPEND="
	dev-libs/glib
	net-libs/libtirpc
	deploypkg? ( dev-libs/libmspack )
	fuse? ( sys-fs/fuse:0 )
	pam? ( sys-libs/pam )
	!pam? ( virtual/libcrypt:= )
	ssl? ( dev-libs/openssl:0= )
	vgauth? (
		dev-libs/libxml2
		dev-libs/xmlsec:=
	)
	X? (
		x11-libs/libXext
		multimon? ( x11-libs/libXinerama )
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXrandr
		x11-libs/libXtst
		x11-libs/libSM
		x11-libs/libXcomposite
		x11-libs/gdk-pixbuf-xlib
		x11-libs/gtk+:3
		gtkmm? (
			dev-cpp/gtkmm:3.0
			dev-libs/libsigc++:2
		)
	)
	dnet? ( dev-libs/libdnet )
	icu? ( dev-libs/icu:= )
	resolutionkms? (
		x11-libs/libdrm[video_cards_vmware]
		virtual/libudev
	)
"

DEPEND="${RDEPEND}
	net-libs/rpcsvc-proto
"

BDEPEND="
	dev-util/glib-utils
	virtual/pkgconfig
	doc? ( app-doc/doxygen )
"

S="${WORKDIR}/${MY_P}"

PATCHES=(
	"${FILESDIR}/10.1.0-Werror.patch"
	"${FILESDIR}/11.3.5-icu.patch"
)

pkg_setup() {
	local CONFIG_CHECK="~VMWARE_BALLOON ~VMWARE_PVSCSI ~VMXNET3"
	use X && CONFIG_CHECK+=" ~DRM_VMWGFX"
	kernel_is -lt 3 9 || CONFIG_CHECK+=" ~VMWARE_VMCI ~VMWARE_VMCI_VSOCKETS"
	kernel_is -lt 3 || CONFIG_CHECK+=" ~FUSE_FS"
	kernel_is -lt 5 5 || CONFIG_CHECK+=" ~X86_IOPL_IOPERM"
	linux-info_pkg_setup
}

src_prepare() {
	eapply -p2 "${PATCHES[@]}"
	eapply_user
	eautoreconf
}

src_configure() {
	# Flatcar: not really upstreamable… We probably can do it with
	# a user patch that replaces `uname -r` in configure.ac with
	# some `portageq best-version sys-kernel/coreos-kernel`.
	local kver
	kver=$(best_version sys-kernel/coreos-kernel)
	kver=${kver#'sys-kernel/coreos-kernel-'}
	kver="${kver%-r+([0-9])}-flatcar"
	local myeconfargs=(
		--disable-glibc-check
		--without-root-privileges
		$(use_enable multimon)
		$(use_with X x)
		$(use_with X gtk3)
		$(use_with gtkmm gtkmm3)
		$(use_enable doc docs)
		--disable-tests
		$(use_enable resolutionkms)
		--disable-static
		$(use_enable deploypkg)
		$(use_with pam)
		$(use_enable vgauth)
		$(use_with dnet)
		$(use_with icu)
		# TODO: Put rules.d file into per-package
		# INSTALL_MASK? We used to disable installing udev
		# files.
		--with-udev-rules-dir="$(get_udevdir)/rules.d"
		# Flatcar: TO UPSTREAM:
		$(use_with fuse fuse 2)
		# Flatcar: TO UPSTREAM:
		--disable-containerinfo
		# Flatcar: TO UPSTREAM:
		--without-gtk2
		# Flatcar: TO UPSTREAM:
		--disable-vmwgfxctrl
		# Flatcar: not really upstreamable…
		--kernel-release="${kver}"
	)
	# Avoid a bug in configure.ac
	use ssl || myeconfargs+=( --without-ssl )

	econf "${myeconfargs[@]}"
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die

	if use pam; then
		rm "${ED}"/etc/pam.d/vmtoolsd || die
		pamd_mimic_system vmtoolsd auth account
		# Flatcar: quick hack
		dodir /usr/share/vmtoolsd/pam.d
		mv "${ED}"/etc/pam.d/vmtoolsd "${ED}"/usr/share/vmtoolsd/pam.d/vmtoolsd
	fi

	newinitd "${FILESDIR}/open-vm-tools.initd" vmware-tools
	newconfd "${FILESDIR}/open-vm-tools.confd" vmware-tools

	if use vgauth; then
		systemd_newunit "${FILESDIR}"/vmtoolsd.vgauth.service vmtoolsd.service
		systemd_dounit "${FILESDIR}"/vgauthd.service
	else
		systemd_dounit "${FILESDIR}"/vmtoolsd.service
	fi

	# Flatcar: TO UPSTREAM:
	if use fuse; then
		# Make fstype = vmhgfs-fuse work in fstab
		dosym vmhgfs-fuse /usr/bin/mount.vmhgfs-fuse
	fi

	if use X; then
		fperms 4711 /usr/bin/vmware-user-suid-wrapper
		dobin scripts/common/vmware-xdg-detect-de
	fi
}

pkg_postinst() {
	udev_reload
}

pkg_postrm() {
	udev_reload
}
