ARCHS = arm64
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpotifyCustomCanvas

SpotifyCustomCanvas_FILES = Tweak.x
SpotifyCustomCanvas_FRAMEWORKS = UIKit AVFoundation CoreMedia
SpotifyCustomCanvas_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
