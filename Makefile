ARCHS := armv7
TARGET := iphone:clang:9.3:5.0
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Neo
Neo_FILES = $(wildcard Sources/*.m) $(wildcard Sources/*.c)
Neo_FRAMEWORKS = UIKit Foundation CoreGraphics Security AVFoundation AudioToolbox MediaPlayer CoreMedia CoreText
Neo_CFLAGS = -fobjc-arc -I$(THEOS)/include -I./include -Wno-align-mismatch -Wno-deprecated-declarations
Neo_LDFLAGS = -L./lib -lcurl -lssl -lcrypto -lz -lopus -logg -Wl,-w

include $(THEOS_MAKE_PATH)/application.mk

after-step::
	@echo "=== Build complete ==="
