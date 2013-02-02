# Distributed under the terms of the GNU General Public License v2

EAPI=2

DESCRIPTION="Virtual for udev implementation and number of its features"
HOMEPAGE=""
SRC_URI=""

LICENSE=""
SLOT="0"
KEYWORDS="~*"
IUSE="+gudev +hwdb keymap selinux static-libs"

DEPEND=""
RDEPEND="gudev? ( <sys-fs/udev-171[extras] )
	hwdb? ( || ( <sys-fs/udev-171[extras] ~sys-fs/udev-141 ) )
	keymap? ( || ( <sys-fs/udev-171[extras] ~sys-fs/udev-141 ) )
	<sys-fs/udev-171[selinux?]"
