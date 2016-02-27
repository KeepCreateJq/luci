#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Wifi Manager
LUCI_DEPENDS:=+luci-mod-admin-full

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
define Package/firewrt/description
  FireWrt Posix Utilities
endef

define Package/firewrt
  SECTION:=sys
  CATEGORY:=System
  TITLE:=FireWrt
endef

define Package/firewrt/description
  FIREWRT POSIX UTILITIES
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef


define Build/Configure
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS) -Wall -fPIC"
endef

define Package/firewrt/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/firewrt.so $(1)/usr/lib/lua/firewrt.so
endef

$(eval $(call BuildPackage,firewrt))
