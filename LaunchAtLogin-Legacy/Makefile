APP_NAME := LaunchAtLogin-Legacy
APP_DIR := $(APP_NAME).app/Contents/MacOS

LAUNCHER_NAME := Launcher
LAUNCHER_DIR := $(LAUNCHER_NAME).app/Contents/MacOS

SYSROOT := $(shell xcrun --sdk macosx --show-sdk-path)
MIN_OS = 11.0

ARCHS := $(addprefix -arch ,x86_64 arm64)
FRAMEWORKS := $(addprefix -framework ,Cocoa Carbon ServiceManagement)
OBJS := $(APP_DIR)/$(APP_NAME) $(LAUNCHER_DIR)/$(LAUNCHER_NAME)

IDENTITY := "PUT_YOUR_DEV_CERT_ID"

all: $(OBJS)

$(APP_DIR)/$(APP_NAME): main.m
	clang $(ARCHS) -isysroot $(SYSROOT) $(FRAMEWORKS) -mmacos-version-min=$(MIN_OS) -fobjc-arc -o $@ $<
	codesign -s $(IDENTITY) $(APP_NAME).app

$(LAUNCHER_DIR)/$(LAUNCHER_NAME): launcher.m
	clang $(ARCHS) -isysroot $(SYSROOT) -framework Cocoa -mmacos-version-min=$(MIN_OS) -fobjc-arc -o $@ $<
	codesign -s $(IDENTITY) $(LAUNCHER_NAME).app
	mkdir -p $(APP_NAME).app/Contents/Library/LoginItems/
	mv $(LAUNCHER_NAME).app $(APP_NAME).app/Contents/Library/LoginItems/

$(OBJS): | $(APP_DIR) $(LAUNCHER_DIR)

$(APP_DIR):
	mkdir -p $(APP_DIR)
	cp $(APP_NAME)-Info.plist $(APP_NAME).app/Contents/Info.plist

$(LAUNCHER_DIR):
	mkdir -p $(LAUNCHER_DIR)
	cp $(LAUNCHER_NAME)-Info.plist $(LAUNCHER_NAME).app/Contents/Info.plist

clean:
	rm -rf $(APP_NAME).app
	rm -rf $(LAUNCHER_NAME).app
