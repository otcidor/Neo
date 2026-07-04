ARCHS := armv7
TARGET := iphone:clang:9.3:6.0
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Neo
Neo_FILES = $(wildcard Sources/*.m)
Neo_FRAMEWORKS = UIKit Foundation CoreGraphics Security AVFoundation AudioToolbox MediaPlayer CoreMedia
Neo_CFLAGS = -fobjc-arc -I$(THEOS)/include
Neo_LDFLAGS =

include $(THEOS_MAKE_PATH)/application.mk

after-step::
	@echo "=== Build complete ==="
