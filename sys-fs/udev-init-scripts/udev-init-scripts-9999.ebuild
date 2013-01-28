# Distributed under the terms of the GNU General Public License v2

EAPI=4

inherit eutils

if [ "${PV}" = "9999" ]; then
	EGIT_REPO_URI="git://git.overlays.gentoo.org/proj/udev-gentoo-scripts.git"
	inherit git-2
fi

DESCRIPTION="udev startup scripts for openrc"
HOMEPAGE="http://www.gentoo.org"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

if [ "${PV}" != "9999" ]; then
	SRC_URI="http://dev.gentoo.org/~williamh/dist/${P}.tar.bz2"
	KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
fi

RESTRICT="test"

DEPEND="virtual/pkgconfig"
RDEPEND=">=virtual/udev-180
	sys-apps/openrc
	!<sys-fs/udev-186"

src_prepare()
{
	epatch_user
}

pkg_postinst()
{
	# If we are building stages, add udev and udev-mount to the default runlevel
	# automatically. mdev-bb is already set to start at sysinit runlevel.
	if use build
	then
		if [[ -x "${ROOT}"/etc/init.d/udev \
			&& -d "${ROOT}"/etc/runlevels/default ]]
		then
			ln -s /etc/init.d/udev "${ROOT}"/etc/runlevels/default/udev
		fi
		if [[ -x "${ROOT}"/etc/init.d/udev-mount \
			&& -d "${ROOT}"/etc/runlevels/default ]]
		then
			ln -s /etc/init.d/udev-mount \
				"${ROOT}"/etc/runlevels/default/udev-mount
		fi
	fi

	# Warn the user about adding the scripts to their sysinit or default runlevel
	if [[ -e "${ROOT}"/etc/runlevels/default ]]
	then
		if [[ ! -e "${ROOT}"/etc/runlevels/sysinit/mdev ]]
		then
			if [[ ! -e "${ROOT}"/etc/runlevels/sysinit/udev ]]
			then
				ewarn
				ewarn "You need to add mdev or udev to the sysinit runlevel."
				ewarn "If you do not do this,"
				ewarn "your system will not be able to boot!"
				ewarn "Run one of these commands:"
				ewarn "\trc-update add mdev sysinit"
				ewarn "\trc-update add udev sysinit"
			fi
			if [[ ! -e "${ROOT}"/etc/runlevels/sysinit/udev-mount ]]
			then
				ewarn
				ewarn "If you use udev instead of mdev in the sysinit runlevel,"
				ewarn "you need to add udev-mount to the sysinit runlevel."
				ewarn "If you do not do this,"
				ewarn "your system will not be able to boot!"
				ewarn "Run this command:"
				ewarn "\trc-update add udev-mount sysinit"
			fi
		else
			if [[ ! -e "${ROOT}"/etc/runlevels/default/udev ]]
			then
				ewarn
				ewarn "If your desktop environment depends on udev, "
				ewarn "you may need to add udev to the default runlevel."
				ewarn "If you do not do this,"
				ewarn "your desktop environment may not work!"
				ewarn "Run this command:"
				ewarn "\trc-update add udev default"
			fi
			if [[ ! -e "${ROOT}"/etc/runlevels/default/udev-mount ]]
			then
				ewarn
				ewarn "If your desktop environment depends on udev, "
				ewarn "you may need to add udev-mount to the default runlevel."
				ewarn "If you do not do this,"
				ewarn "your desktop environment may not work!"
				ewarn "Run this command:"
				ewarn "\trc-update add udev-mount default"
			fi
		fi
	fi

	if [[ -x $(type -P rc-update) ]] && rc-update show | grep udev-postmount | grep -qs 'boot\|default\|sysinit'; then
		ewarn "The udev-postmount service has been removed because the reasons for"
		ewarn "its existance have been removed upstream."
		ewarn "Please remove it from your runlevels."
	fi
}
