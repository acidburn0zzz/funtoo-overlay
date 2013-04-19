# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit multilib

RESTRICT="strip"

# language IUSE:
IUSE="ada cxx fortran f77 f95 objc openmp"
# other IUSE:
IUSE="$IUSE multislot nls nptl test vanilla doc multilib altivec"

if use multislot; then
	SLOT="${PV}"
else
	SLOT="${PV%.*}"
fi

PATCH_VER="1.6"
GMP_VER="5.1.1"
MPFR_VER="3.1.2"
MPC_VER="1.0.1"
GCC_A="gcc-${PV}.tar.bz2"

SRC_URI="mirror://gnu/gcc/gcc-${PV}/${GCC_A}"
SRC_URI="$SRC_URI http://www.multiprecision.org/mpc/download/mpc-${MPC_VER}.tar.gz"
SRC_URI="$SRC_URI http://www.mpfr.org/mpfr-${MPFR_VER}/mpfr-${MPFR_VER}.tar.xz"
SRC_URI="$SRC_URI mirror://gnu/gmp/gmp-${GMP_VER}.tar.xz"

DESCRIPTION="The GNU Compiler Collection"

LICENSE="GPL-3 LGPL-3 || ( GPL-3 libgcc libstdc++ gcc-runtime-library-exception-3.1 ) FDL-1.2"
KEYWORDS="*"

RDEPEND="sys-libs/zlib nls? ( sys-devel/gettext ) virtual/libiconv"
DEPEND="${RDEPEND} >=sys-devel/bison-1.875 >=sys-devel/flex-2.5.4 elibc_glibc? ( >=sys-libs/glibc-2.8 ) >=sys-devel/binutils-2.18"
PDEPEND=">=sys-devel/gcc-config-1.7 elibc_glibc? ( >=sys-libs/glibc-2.8 )"

pkg_setup() {
	PREFIX=/usr
	CTARGET=$CHOST
	GCC_BRANCH_VER=${SLOT}
	GCC_CONFIG_VER=${PV}
	DATAPATH=${PREFIX}/share/gcc-data/${CTARGET}/${GCC_CONFIG_VER}
	BINPATH=${PREFIX}/${CTARGET}/gcc-bin/${GCC_CONFIG_VER}
	STDCXX_INCDIR=${PREFIX}/lib/gcc/${CTARGET}/${GCC_CONFIG_VER}/include/g++-v${GCC_BRANCH_VER}
	LIBPATH=${PREFIX}/lib/gcc/${CTARGET}/${GCC_BRANCH_VER/\.*/}
}

src_unpack() {
	unpack $GCC_A
	( unpack mpc-${MPC_VER}.tar.gz && mv ${WORKDIR}/mpc-${MPC_VER} ${S}/mpc ) || die "mpc setup fail"
	( unpack mpfr-${MPFR_VER}.tar.xz && mv ${WORKDIR}/mpfr-${MPFR_VER} ${S}/mpfr ) || die "mpfr setup fail"
	( unpack gmp-${GMP_VER}.tar.xz && mv ${WORKDIR}/gmp-${GMP_VER} ${S}/gmp ) || die "gmp setup fail"
	cd $S
	[[ ${CHOST} == ${CTARGET} ]] && cat "${FILESDIR}"/gcc-spec-env.patch | patch -p1 || die "patch fail"
	mkdir ${WORKDIR}/objdir
}

src_configure() {

	# Determine language support:

	local confgcc
	local GCC_LANC="c"
	use cxx && GCC_LANG+=",c++" && confgcc+=" --enable-libstdcxx-time"
	use objc && GCC_LANG+=",objc" && confgcc+=" --enable-objc-gc"
	use fortran && GCC_LANG+=",fortran" || confgcc+=" --disable-libquadmath"
	use f77 && GCC_LANG+=",f77"
	use f95 && GCC_LANG+=",f95"
	use ada && GCC_LANG+=",ada"
	confgcc+=" $(use_enable openmp libgomp)"
	confgcc+=" --enable-languages=${GCC_LANG} --disable-libgcj"

	cd ${WORKDIR}/objdir && ../gcc-${PV}/configure \
		$(use_enable multilib) \
		--prefix=${PREFIX} \
		--bindir=${BINPATH} \
		--includedir=${LIBPATH}/include \
		--datadir=${DATAPATH} \
		--mandir=${DATAPATH}/man \
		--infodir=${DATAPATH}/info \
		--with-gxx-include-dir=${STDCXX_INCDIR} \
		--host=$CHOST \
		--target=$CTARGET \
		--disable-ppl \
		--disable-cloog \
		--with-system-zlib \
		--enable-obsolete \
		--disable-werror \
		--enable-secureplt \
		--disable-lto \
		--with-bugurl=http://bugs.funtoo.org \
		--with-pkgversion="Funtoo ${PVR}" \
		$confgcc \
		|| die "configure fail"
}

src_compile() {
	cd $WORKDIR/objdir
	unset ABI
	emake
}

create_gcc_env_entry() {
	dodir /etc/env.d/gcc
	local gcc_envd_base="/etc/env.d/gcc/${CTARGET}-${GCC_CONFIG_VER}"

	local gcc_specs_file
	local gcc_envd_file="${D}${gcc_envd_base}"
	if [[ -z $1 ]] ; then
		# I'm leaving the following commented out to remind me that it
		# was an insanely -bad- idea. Stuff broke. GCC_SPECS isnt unset
		# on chroot or in non-toolchain.eclass gcc ebuilds!
		#gcc_specs_file="${LIBPATH}/specs"
		gcc_specs_file=""
	else
		gcc_envd_file+="-$1"
		gcc_specs_file="${LIBPATH}/$1.specs"
	fi
	# We want to list the default ABI's LIBPATH first so libtool
	# searches that directory first.  This is a temporary
	# workaround for libtool being stupid and using .la's from
	# conflicting ABIs by using the first one in the search path
	local ldpaths mosdirs
	local mdir mosdir abi ldpath
	for abi in $(get_all_abis TARGET) ; do
		mdir=$($(XGCC) $(get_abi_CFLAGS ${abi}) --print-multi-directory)
		ldpath=${LIBPATH}
		[[ ${mdir} != "." ]] && ldpath+="/${mdir}"
		ldpaths="${ldpath}${ldpaths:+:${ldpaths}}"
		mosdir=$($(XGCC) $(get_abi_CFLAGS ${abi}) -print-multi-os-directory)
		mosdirs="${mosdir}${mosdirs:+:${mosdirs}}"
	done

	cat <<-EOF > ${gcc_envd_file}
	PATH="${BINPATH}"
	ROOTPATH="${BINPATH}"
	GCC_PATH="${BINPATH}"
	LDPATH="${ldpaths}"
	MANPATH="${DATAPATH}/man"
	INFOPATH="${DATAPATH}/info"
	STDCXX_INCDIR="${STDCXX_INCDIR##*/}"
	CTARGET="${CTARGET}"
	GCC_SPECS="${gcc_specs_file}"
	MULTIOSDIRS="${mosdirs}"
	EOF
}

linkify_compiler_binaries() {
	dodir /usr/bin
	cd "${D}"${BINPATH}
	# Ugh: we really need to auto-detect this list.
	#      It's constantly out of date.
	for x in cpp gcc g++ c++ gcov g77 gcj gcjh gfortran gccgo ; do
		# For some reason, g77 gets made instead of ${CTARGET}-g77...
		# this should take care of that
		[[ -f ${x} ]] && mv ${x} ${CTARGET}-${x}

		if [[ -f ${CTARGET}-${x} ]] ; then
			ln -sf ${CTARGET}-${x} ${x}
			dosym ${BINPATH}/${CTARGET}-${x} /usr/bin/${x}-${GCC_CONFIG_VER}
			# Create version-ed symlinks
			dosym ${BINPATH}/${CTARGET}-${x} /usr/bin/${CTARGET}-${x}-${GCC_CONFIG_VER}
		fi

		if [[ -f ${CTARGET}-${x}-${GCC_CONFIG_VER} ]] ; then
			rm -f ${CTARGET}-${x}-${GCC_CONFIG_VER}
			ln -sf ${CTARGET}-${x} ${CTARGET}-${x}-${GCC_CONFIG_VER}
		fi
	done
}

tasteful_stripping() {
	# Now do the fun stripping stuff
	env RESTRICT="" CHOST=${CHOST} prepstrip "${D}${BINPATH}"
	env RESTRICT="" CHOST=${CTARGET} prepstrip "${D}${LIBPATH}"
	# gcc used to install helper binaries in lib/ but then moved to libexec/
	[[ -d ${D}${PREFIX}/libexec/gcc ]] && \
		env RESTRICT="" CHOST=${CHOST} prepstrip "${D}${PREFIX}/libexec/gcc/${CTARGET}/${GCC_CONFIG_VER}"
}

doc_cleanups() {
	local cxx_mandir=$(find "${WORKDIR}/objdir/${CTARGET}/libstdc++-v3" -name man)
	if [[ -d ${cxx_mandir} ]] ; then
		# clean bogus manpages #113902
		find "${cxx_mandir}" -name '*_build_*' -exec rm {} \;
		cp -r "${cxx_mandir}"/man? "${D}/${DATAPATH}"/man/
	fi
	has noinfo ${FEATURES} \
		&& rm -r "${D}/${DATAPATH}"/info \
		|| prepinfo "${DATAPATH}"
	has noman ${FEATURES} \
		&& rm -r "${D}/${DATAPATH}"/man \
		|| prepman "${DATAPATH}"
}

# make sure the libtool archives have libdir set to where they actually
# -are-, and not where they -used- to be.  also, any dependencies we have
# on our own .la files need to be updated.
fix_libtool_libdir_paths() {
	pushd "${D}" >/dev/null

	pushd "./${1}" >/dev/null
	local dir="${PWD#${D%/}}"
	local allarchives=$(echo *.la)
	allarchives="\(${allarchives// /\\|}\)"
	popd >/dev/null

	sed -i \
		-e "/^libdir=/s:=.*:='${dir}':" \
		./${dir}/*.la
	sed -i \
		-e "/^dependency_libs=/s:/[^ ]*/${allarchives}:${LIBPATH}/\1:g" \
		$(find ./${PREFIX}/lib* -maxdepth 3 -name '*.la') \
		./${dir}/*.la

	popd >/dev/null
}

get_make_var() {
	local var=$1 makefile=${2:-${WORKDIR}/objdir/Makefile}
	echo -e "e:\\n\\t@echo \$(${var})\\ninclude ${makefile}" | \
		r=${makefile%/*} emake --no-print-directory -s -f - 2>/dev/null
}
XGCC() { get_make_var GCC_FOR_TARGET ; }

gcc_movelibs() {
	local x multiarg removedirs=""
	for multiarg in $($(XGCC) -print-multi-lib) ; do
		multiarg=${multiarg#*;}
		multiarg=${multiarg//@/ -}

		local OS_MULTIDIR=$($(XGCC) ${multiarg} --print-multi-os-directory)
		local MULTIDIR=$($(XGCC) ${multiarg} --print-multi-directory)
		local TODIR=${D}${LIBPATH}/${MULTIDIR}
		local FROMDIR=

		[[ -d ${TODIR} ]] || mkdir -p ${TODIR}

		for FROMDIR in \
			${LIBPATH}/${OS_MULTIDIR} \
			${LIBPATH}/../${MULTIDIR} \
			${PREFIX}/lib/${OS_MULTIDIR} \
			${PREFIX}/${CTARGET}/lib/${OS_MULTIDIR}
		do
			removedirs="${removedirs} ${FROMDIR}"
			FROMDIR=${D}${FROMDIR}
			if [[ ${FROMDIR} != "${TODIR}" && -d ${FROMDIR} ]] ; then
				local files=$(find "${FROMDIR}" -maxdepth 1 ! -type d 2>/dev/null)
				if [[ -n ${files} ]] ; then
					mv ${files} "${TODIR}"
				fi
			fi
		done
		fix_libtool_libdir_paths "${LIBPATH}/${MULTIDIR}"

		# SLOT up libgcj.pc if it's available (and let gcc-config worry about links)
		FROMDIR="${PREFIX}/lib/${OS_MULTIDIR}"
		for x in "${D}${FROMDIR}"/pkgconfig/libgcj*.pc ; do
			[[ -f ${x} ]] || continue
			sed -i "/^libdir=/s:=.*:=${LIBPATH}/${MULTIDIR}:" "${x}"
			mv "${x}" "${D}${FROMDIR}"/pkgconfig/libgcj-${GCC_PV}.pc || die
		done
	done

	# We remove directories separately to avoid this case:
	#	mv SRC/lib/../lib/*.o DEST
	#	rmdir SRC/lib/../lib/
	#	mv SRC/lib/../lib32/*.o DEST  # Bork
	for FROMDIR in ${removedirs} ; do
		rmdir "${D}"${FROMDIR} >& /dev/null
	done
	find "${D}" -type d | xargs rmdir >& /dev/null
}

src_install() {
	S=$WORKDIR/objdir; cd $S

# PRE-MAKE INSTALL SECTION:

	# from toolchain eclass:
	# Do allow symlinks in private gcc include dir as this can break the build
	find gcc/include*/ -type l -delete
	# Remove generated headers, as they can cause things to break
	# (ncurses, openssl, etc).

	while read x; do
		grep -q 'It has been auto-edited by fixincludes from' "${x}" \
			&& echo "Removing auto-generated header: $x" \
			&& rm -f "${x}"
	done < <(find gcc/include*/ -name '*.h')

# MAKE INSTALL SECTION:

	make -j1 DESTDIR="${D}" install || die

# POST MAKE INSTALL SECTION:

	# Move the libraries to the proper location
	gcc_movelibs

	# Basic sanity check
	local EXEEXT
	eval $(grep ^EXEEXT= "${WORKDIR}"/objdir/gcc/config.log)
	[[ -r ${D}${BINPATH}/gcc${EXEEXT} ]] || die "gcc not found in ${D}"

# CLEANUPS:

	# Punt some tools which are really only useful while building gcc
	find "${D}" -name install-tools -prune -type d -exec rm -rf "{}" \;
	# This one comes with binutils
	find "${D}" -name libiberty.a -delete
	# prune empty dirs left behind
	find "${D}" -depth -type d -delete 2>/dev/null
	# Use gid of 0 because some stupid ports don't have
	# the group 'root' set to gid 0.  Send to /dev/null
	# for people who are testing as non-root.
	chown -R root:0 "${D}"${LIBPATH} 2>/dev/null
	find "${D}/${LIBPATH}" -name libstdc++.la -type f -exec rm "{}" \;

# GENTOO ENV SETUP

	dodir /etc/env.d/gcc
	create_gcc_env_entry
	linkify_compiler_binaries
	tasteful_stripping
	doc_cleanups

	# Rather install the script, else portage with changing $FILESDIR
	# between binary and source package borks things ....
	insinto "${DATAPATH}"
	newins "${FILESDIR}"/awk/fixlafiles.awk-no_gcc_la fixlafiles.awk || die
	exeinto "${DATAPATH}"
	doexe "${FILESDIR}"/fix_libtool_files.sh || die
	doexe "${FILESDIR}"/c{89,99} || die

# Don't scan .gox files for executable stacks - false positives
export QA_EXECSTACK="usr/lib*/go/*/*.gox"
export QA_WX_LOAD="usr/lib*/go/*/*.gox"

}
