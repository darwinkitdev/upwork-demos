APP_NAME := DisplayTint
APP_DIR := $(APP_NAME).app/Contents/MacOS

SYSROOT := $(shell xcrun --sdk macosx --show-sdk-path)
MIN_OS = 11.0

ARCHS := $(addprefix -arch ,x86_64 arm64)
FRAMEWORKS := $(addprefix -framework ,Cocoa DisplayServices)
OBJS := $(APP_NAME).app/Contents/Info.plist $(APP_DIR)/$(APP_NAME)

all: $(OBJS)

$(APP_DIR)/$(APP_NAME): main.m
	clang $(ARCHS) -isysroot $(SYSROOT) $(FRAMEWORKS) -F/System/Library/PrivateFrameworks -mmacos-version-min=$(MIN_OS) -fobjc-arc -o $@ $<
	codesign --deep --force --sign - $(APP_NAME).app

$(OBJS): | $(APP_DIR)

$(APP_DIR):
	mkdir -p $(APP_DIR)

$(APP_NAME).app/Contents/Info.plist:
	cp Info.plist $@

clean:
	rm -rf $(APP_NAME).app
