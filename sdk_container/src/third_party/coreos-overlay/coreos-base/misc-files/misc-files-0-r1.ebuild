# Copyright (c) 2023 The Flatcar Maintainers.
# Distributed under the terms of the GNU General Public License v2

EAPI=8

TMPFILES_OPTIONAL=1
inherit systemd tmpfiles

DESCRIPTION='Flatcar miscellaneous files'
HOMEPAGE='https://www.flatcar.org/'

LICENSE='Apache-2.0'
SLOT='0'
KEYWORDS='amd64 arm64'
IUSE="openssh"

# No source directory.
S="${WORKDIR}"

# Versions listed below are version of packages that shedded the
# modifications in their ebuilds.
#
# net-misc/openssh must be installed on host for enabling its unit to
# work during installation.
DEPEND="
	openssh? ( >=net-misc/openssh-9.3_p2-r1 )
"

# Versions listed below are version of packages that shedded the
# modifications in their ebuilds.
RDEPEND="
	${DEPEND}
	>=app-shells/bash-5.2_p15-r2
"

declare -A CORE_BASH_SYMLINKS
CORE_BASH_SYMLINKS=(
    ['.bash_logout']='../../usr/share/flatcar/etc/skel/.bash_logout'
    ['.bash_profile']='../../usr/share/flatcar/etc/skel/.bash_profile'
    ['.bashrc']='../../usr/share/flatcar/etc/skel/.bashrc'
)

src_compile() {
    # An empty file for temporary symlink destinations under
    # /usr/share/flatcar/etc.
    touch "${T}/empty-file"
    # Generate the tmpfiles config file for bash symlinks in core home
    # directory.
    local name config config_tmp target
    config="${T}/home-core-bash-symlinks.conf"
    config_tmp="${config}.tmp"
    truncate --size 0 "${config_tmp}"
    for name in "${!CORE_BASH_SYMLINKS[@]}"; do
        target=${CORE_BASH_SYMLINKS["${name}"]}
        echo "L /home/core/${name} - core core - ${target}" >>"${config_tmp}"
    done
    LC_ALL=C sort "${config_tmp}" >"${config}"
}

src_install() {
    # Use absolute paths to be clear about what locations are used. The
    # dosym below will make relative paths out of them.
    #
    # For files inside /usr/share/flatcar/etc the ebuild will create empty
    # files to avoid having dangling symlinks. During the assembly of the
    # image, the /usr/share/flatcar/etc directory will be removed, and
    # /etc will be moved in its place.
    #
    # These links exist because old installations can still have
    # references to them.
    local -A compat_symlinks
    compat_symlinks=(
        ['/usr/share/bash/bash_logout']='/usr/share/flatcar/etc/bash/bash_logout'
        ['/usr/share/bash/bashrc']='/usr/share/flatcar/etc/bash/bashrc'
        ['/usr/share/skel/.bash_logout']='/usr/share/flatcar/etc/skel/.bash_logout'
        ['/usr/share/skel/.bash_profile']='/usr/share/flatcar/etc/skel/.bash_profile'
        ['/usr/share/skel/.bashrc']='/usr/share/flatcar/etc/skel/.bashrc'
    )
    if use openssh; then
        compat_symlinks+=(
            ['/usr/share/ssh/ssh_config']='/usr/share/flatcar/etc/ssh/ssh_config.d/50-flatcar.conf'
            ['/usr/share/ssh/sshd_config']='/usr/share/flatcar/etc/ssh/sshd_config.d/50-flatcar.conf'
        )
    fi

    local link target
    for link in "${!compat_symlinks[@]}"; do
        target=${compat_symlinks["${link}"]}
        dosym -r "${target}" "${link}"
        if [[ "${target}" = /usr/share/flatcar/etc/* ]]; then
            insinto "${target%/*}"
            newins "${T}/empty-file" "${target##*/}"
        fi
    done

    insinto '/etc/bash/bashrc.d'
    doins "${FILESDIR}/99-flatcar-bcc"

    dotmpfiles "${T}/home-core-bash-symlinks.conf"
    # Ideally we would be calling systemd-tmpfiles to create the
    # symlinks, but at this point systemd may not have any info about
    # the core user. Thus we hardcode the id 500.
    dodir /home/core
    fowners 500:500 /home/core
    local name
    for name in "${!CORE_BASH_SYMLINKS[@]}"; do
        target=${CORE_BASH_SYMLINKS["${name}"]}
        link="/home/core/${name}"
        dosym "${target}" "${link}"
        fowners --no-dereference 500:500 "${link}"
    done

    if use openssh; then
        # Install our configuration snippets.
        insinto /etc/ssh/ssh_config.d
        doins "${FILESDIR}/50-flatcar-ssh.conf"
        insinto /etc/ssh/sshd_config.d
        doins "${FILESDIR}/50-flatcar-sshd.conf"

        # Install our socket drop-in file that disables the rate
        # limiting on the sshd socket.
        local override_dir
        override_dir="$(systemd_get_systemunitdir)/sshd.socket.d"
        dodir "${override_dir}"
        insinto "${override_dir}"
        doins "${FILESDIR}/no-trigger-limit-burst.conf"

        # Enable some sockets that aren't enabled by their own ebuilds.
        systemd_enable_service sockets.target sshd.socket
    fi
}
