# Distributed under the terms of the GNU General Public License v2

EAPI=2

DESCRIPTION="Virtual for udev implementation and number of its features"
HOMEPAGE=""
SRC_URI=""

LICENSE=""
SLOT="0"
KEYWORDS="*"
IUSE="+gudev +hwdb introspection keymap selinux static-libs"
DEPEND=""
RDEPEND="~sys-fs/udev-171[gudev?,hwdb?,introspection?,keymap?,selinux?]"
