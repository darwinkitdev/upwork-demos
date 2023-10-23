APP_NAME := MenuShot
APP_DIR := $(APP_NAME).app/Contents/MacOS
RESOURCES_DIR := $(APP_NAME).app/Contents/Resources
RESOURCES := screenshotselection.pdf screenshotwindow.pdf

SYSROOT := $(shell xcrun --sdk macosx --show-sdk-path)

ARCHS := $(addprefix -arch ,x86_64 arm64)
FRAMEWORKS := $(addprefix -framework ,Cocoa Carbon ServiceManagement AudioToolbox)
OBJS := $(RESOURCES) $(APP_DIR)/$(APP_NAME)

all: $(OBJS)

$(APP_DIR)/$(APP_NAME): main.m
	clang $(ARCHS) -isysroot $(SYSROOT) $(FRAMEWORKS) -lobjc -o $@ $<

$(OBJS): | $(APP_DIR)

$(APP_DIR):
	mkdir -p $(APP_DIR)
	cp $(APP_NAME)-Info.plist $(APP_NAME).app/Contents/Info.plist

$(RESOURCES_DIR):
	mkdir -p $(RESOURCES_DIR)

$(RESOURCES): $(RESOURCES_DIR)
	cp $@ $(RESOURCES_DIR)/$@

clean:
	rm -rf $(APP_NAME).app
