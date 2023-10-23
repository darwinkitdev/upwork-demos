APP_NAME := LaunchAtLogin-Modern
APP_DIR := $(APP_NAME).app/Contents/MacOS

SYSROOT := $(shell xcrun --sdk macosx --show-sdk-path)

ARCHS := $(addprefix -arch ,x86_64 arm64)
FRAMEWORKS := $(addprefix -framework ,Cocoa ServiceManagement)
OBJS := $(APP_NAME).app/Contents/Info.plist $(APP_DIR)/$(APP_NAME)

IDENTITY := "PUT_YOUR_DEV_CERT_ID"

all: $(OBJS)

$(APP_DIR)/$(APP_NAME): main.m
	clang $(ARCHS) -isysroot $(SYSROOT) $(FRAMEWORKS) -lobjc -o $@ $<
	codesign -s $(IDENTITY) $(APP_NAME).app

$(OBJS): | $(APP_DIR)

$(APP_DIR):
	mkdir -p $(APP_DIR)

$(APP_NAME).app/Contents/Info.plist:
	cp Info.plist $@

clean:
	rm -rf $(APP_NAME).app