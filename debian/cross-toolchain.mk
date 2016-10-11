#
# This makefile allows to quickly build minimalistic cross-compilers
# for various targets. They only support the C language and do not
# support a C library.
#

# Support multiple makes at once based on number of processors
ifneq (,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
njobs = -j $(patsubst parallel=%,%,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
endif

gcc_major_version     = 6

# GCC does not build with some hardening options and anyway we do not
# ship the resulting binaries in the package
toolchain_build_flags = CFLAGS="-g -O2" CXXFLAGS="-g -O2" CPPFLAGS="" LDFLAGS=""

target                = $(filter-out %_,$(subst _,_ ,$@))
toolchain_dir         = $(CURDIR)/cross-toolchain
stamp                 = $(toolchain_dir)/stamp-
binutils_src_dir      = /usr/src/binutils
binutils_unpack_dir   = $(toolchain_dir)/binutils-source
binutils_build_dir    = $(toolchain_dir)/binutils-$(target)
gcc_src_dir           = /usr/src/gcc-$(gcc_major_version)
gcc_unpack_dir        = $(toolchain_dir)/gcc-source
gcc_build_dir         = $(toolchain_dir)/gcc-$(target)

# Use only xtensa-specific patches on top of upstream version
binutils_patch        = local/patches/binutils.patch
gcc_patch             = local/patches/gcc.patch

$(stamp)binutils_unpack:
	mkdir -p $(binutils_unpack_dir)
	cd $(binutils_unpack_dir) && \
		tar --strip-components=1 -xf $(binutils_src_dir)/binutils-*.tar.* && \
		cat $(CURDIR)/$(binutils_patch) | patch -p1 && \
		cat $(CURDIR)/local/patches/binutils-2.27_fixup.patch | patch -p1
	touch $@

$(stamp)binutils_%: $(stamp)binutils_unpack
	mkdir -p $(binutils_build_dir)
	cd $(binutils_build_dir) && \
		$(binutils_unpack_dir)/configure \
			--build=$(DEB_BUILD_GNU_TYPE) \
			--host=$(DEB_HOST_GNU_TYPE) \
			--target=$(target) \
			--prefix=$(toolchain_dir) \
			--disable-nls \
			--disable-plugins \
			$(toolchain_build_flags)
	$(MAKE) $(njobs) -C $(binutils_build_dir) all
	$(MAKE) $(njobs) -C $(binutils_build_dir) install
	touch $@

$(stamp)gcc_unpack:
	mkdir -p $(gcc_unpack_dir)
	cd $(gcc_unpack_dir) && \
		tar --strip-components=1 -xf $(gcc_src_dir)/gcc-*.tar.* && \
		cat $(CURDIR)/$(gcc_patch) | patch -p1 && \
		cat $(gcc_src_dir)/patches/gcc-gfdl-build.diff | patch -p2
	touch $@

$(stamp)gcc_%: $(stamp)binutils_% $(stamp)gcc_unpack
	mkdir -p $(gcc_build_dir)
	cd $(gcc_build_dir) && \
		$(gcc_unpack_dir)/configure \
			--build=$(DEB_BUILD_GNU_TYPE) \
			--host=$(DEB_HOST_GNU_TYPE) \
			--target=$(target) \
			--prefix=$(toolchain_dir) \
			--enable-languages="c" \
			--disable-multilib \
			--disable-libffi \
			--disable-libgomp \
			--disable-libmudflap \
			--disable-libquadmath \
			--disable-libssp \
			--disable-nls \
			--disable-shared \
			--disable-threads \
			--disable-tls \
			--disable-plugins \
			--with-gnu-as \
			--with-gnu-ld \
			--with-headers=no \
			--without-newlib \
			$(toolchain_build_flags)
	$(MAKE) $(njobs) -C $(gcc_build_dir) all
	$(MAKE) $(njobs) -C $(gcc_build_dir) install
	touch $@
