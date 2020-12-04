GMP_VER=6.2.1
GMP_URL=https://ftp.gnu.org/gnu/gmp/gmp-$(GMP_VER).tar.bz2
GMP_TAR=gmp-$(GMP_VER).tar.bz2
GMP_DIR=gmp-$(GMP_VER)
GMP_SUM=eae9326beb4158c386e39a356818031bd28f3124cf915f8c5b1dc4c7a36b4d7c

MPFR_VER=4.1.0
MPFR_URL=https://ftp.gnu.org/gnu/mpfr/mpfr-$(MPFR_VER).tar.bz2
MPFR_TAR=mpfr-$(MPFR_VER).tar.bz2
MPFR_DIR=mpfr-$(MPFR_VER)
MPFR_SUM=feced2d430dd5a97805fa289fed3fc8ff2b094c02d05287fd6133e7f1f0ec926

MPC_VER=1.2.1
MPC_URL=https://ftp.gnu.org/gnu/mpc/mpc-$(MPC_VER).tar.gz
MPC_TAR=mpc-$(MPC_VER).tar.gz
MPC_DIR=mpc-$(MPC_VER)
MPC_SUM=17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459

BINUTILS_VER=2.35.1
BINUTILS_URL=https://ftp.gnu.org/gnu/binutils/binutils-$(BINUTILS_VER).tar.bz2
BINUTILS_TAR=binutils-$(BINUTILS_VER).tar.bz2
BINUTILS_DIR=binutils-$(BINUTILS_VER)
BINUTILS_PATCHES=local/patches/binutils-2.34_fixup.patch local/patches/binutils.patch
BINUTILS_SUM=320e7a1d0f46fcd9f413f1046e216cbe23bb2bce6deb6c6a63304425e48b1942

GCC_VER=10.2.0
GCC_URL=https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VER)/gcc-$(GCC_VER).tar.gz
GCC_TAR=gcc-$(GCC_VER).tar.gz
GCC_DIR=gcc-$(GCC_VER)
GCC_PATCHES=local/patches/gcc.patch
GCC_SUM=27e879dccc639cd7b0cc08ed575c1669492579529b53c9ff27b0b96265fa867d

BASEDIR=$(shell pwd)
TOOLCHAIN_DIR=$(BASEDIR)/toolchain
TARGET=xtensa-elf
DL_DIR=$(TOOLCHAIN_DIR)/dl
BUILD_DIR=$(TOOLCHAIN_DIR)/build

all: toolchain

# 1: package name
# 2: configure arguments
# 3: make command
define Common/Compile
	mkdir -p $(BUILD_DIR)/$($(1)_DIR)
	+cd $(BUILD_DIR)/$($(1)_DIR) && \
	$(DL_DIR)/$($(1)_DIR)/configure \
		--prefix=$(TOOLCHAIN_DIR)/inst \
		$(2) && \
	$(3)
endef

define GMP/Compile
	$(call Common/Compile,GMP, \
		--disable-shared --enable-static, \
		$(MAKE) && $(MAKE) check && $(MAKE) -j1 install \
	)
endef

define MPFR/Compile
	$(call Common/Compile,MPFR, \
		--disable-shared --enable-static \
		--with-gmp=$(TOOLCHAIN_DIR)/inst, \
		$(MAKE) && $(MAKE) check && $(MAKE) -j1 install \
	)
endef

define MPC/Compile
	$(call Common/Compile,MPC, \
		--disable-shared --enable-static \
		--with-gmp=$(TOOLCHAIN_DIR)/inst \
		--with-mpfr=$(TOOLCHAIN_DIR)/inst, \
		$(MAKE) && $(MAKE) check && $(MAKE) -j1 install \
	)
endef

define BINUTILS/Compile
	$(call Common/Compile,BINUTILS, \
		--target=$(TARGET) \
		--disable-werror, \
		$(MAKE) && $(MAKE) -j1 install \
	)
endef

define GCC/Compile
	$(call Common/Compile,GCC, \
		--target=$(TARGET) \
		--enable-languages=c \
		--disable-libssp \
		--disable-shared \
		--disable-libquadmath \
		--with-gmp=$(TOOLCHAIN_DIR)/inst \
		--with-mpfr=$(TOOLCHAIN_DIR)/inst \
		--with-mpc=$(TOOLCHAIN_DIR)/inst \
		--with-newlib, \
		$(MAKE) && $(MAKE) -j1 install \
	)
endef

# 1: package name
# 2: dependencies on other packages
define Build
$(DL_DIR)/$($(1)_TAR):
	mkdir -p $(DL_DIR)
	wget -N -P $(DL_DIR) $($(1)_URL)
	printf "%s  %s\n" $($(1)_SUM) $$@ | shasum -a 256 -c

$(DL_DIR)/$($(1)_DIR)/.prepared: $(DL_DIR)/$($(1)_TAR)
	tar -C $(DL_DIR) -x$(if $(findstring bz2,$($(1)_TAR)),j,z)f $(DL_DIR)/$($(1)_TAR)
	$(if $($(1)_PATCHES), \
		cat $($(1)_PATCHES) | \
		patch -p1 -d $(DL_DIR)/$($(1)_DIR))
	touch $$@

$(1)_DEPENDS = $(foreach pkg,$(2),$(BUILD_DIR)/$($(pkg)_DIR)/.built)
$(BUILD_DIR)/$($(1)_DIR)/.built: $(DL_DIR)/$($(1)_DIR)/.prepared $$($(1)_DEPENDS)
	mkdir -p $(BUILD_DIR)/$($(1)_DIR)
	$($(1)/Compile)
	touch $$@

clean-dl-$(1):
	rm -rf $(DL_DIR)/$($(1)_DIR)

toolchain: $(BUILD_DIR)/$($(1)_DIR)/.built
clean-dl: clean-dl-$(1)
download: $(DL_DIR)/$($(1)_DIR)/.prepared

endef

all: toolchain firmware
toolchain-clean:
	rm -rf $(TOOLCHAIN_DIR)/build $(TOOLCHAIN_DIR)/inst
clean-dl:
download:
toolchain:

clean:
	$(MAKE) -C target_firmware clean

firmware: toolchain
	+$(MAKE) -C target_firmware

.PHONY: all toolchain-clean clean clean-dl download toolchain firmware

$(eval $(call Build,GMP))
$(eval $(call Build,MPFR,GMP))
$(eval $(call Build,MPC,GMP MPFR))
$(eval $(call Build,BINUTILS))
$(eval $(call Build,GCC,MPC MPFR))
