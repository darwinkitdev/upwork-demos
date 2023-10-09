APP_NAME := MenuShot
APP_DIR := $(APP_NAME).app/Contents/MacOS
RESOURCES_DIR := $(APP_NAME).app/Contents/Resources
RESOURCES := screenshotselection.pdf screenshotwindow.pdf

LAUNCHER_NAME := Launcher
LAUNCHER_DIR := $(LAUNCHER_NAME).app/Contents/MacOS

ARCHS := $(addprefix -arch ,x86_64 arm64)
FRAMEWORKS := $(addprefix -framework ,Cocoa Carbon ServiceManagement AudioToolbox)
OBJS := $(RESOURCES) $(APP_DIR)/$(APP_NAME) $(LAUNCHER_DIR)/$(LAUNCHER_NAME)

IDENTITY := "PUT_YOUR_DEV_CERT_ID"

all: $(OBJS)

$(APP_DIR)/$(APP_NAME): main.m
	clang $(ARCHS) $(FRAMEWORKS) -lobjc -o $@ $<
	codesign -s $(IDENTITY) $(APP_NAME).app

$(LAUNCHER_DIR)/$(LAUNCHER_NAME): launcher.m
	clang $(ARCHS) -framework Cocoa -lobjc -o $@ $<
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

$(RESOURCES_DIR):
	mkdir -p $(RESOURCES_DIR)

$(RESOURCES): $(RESOURCES_DIR)
	cp $@ $(RESOURCES_DIR)/$@

clean:
	rm -rf $(APP_NAME).app
