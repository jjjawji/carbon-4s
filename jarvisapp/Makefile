ARCHS = armv7
TARGET = iphone:clang:10.3:9.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Jarvis

Jarvis_FILES = main.m AppDelegate.m RootViewController.m
Jarvis_FRAMEWORKS = UIKit Foundation CoreGraphics
Jarvis_CFLAGS = -fobjc-arc -Wno-error=deprecated-module-dot-map
Jarvis_USE_MODULES = 0
Jarvis_CODESIGN_FLAGS = -S

include $(THEOS_MAKE_PATH)/application.mk



