# SGFPlayerScreensaver Build Configuration
# Makefile for building screensaver on macOS Sequoia v15.5

# Configuration
PRODUCT_NAME = SGFPlayerScreensaver
BUNDLE_IDENTIFIER = com.sgfplayer.screensaver
DEPLOYMENT_TARGET = 12.0
SWIFT_VERSION = 5

# Paths
BUILD_DIR = build
SOURCES_DIR = Sources
FRAMEWORKS_DIR = /System/Library/Frameworks
SCREENSAVER_FRAMEWORK = $(FRAMEWORKS_DIR)/ScreenSaver.framework

# Source files
SWIFT_SOURCES = $(shell find $(SOURCES_DIR) -name "*.swift")
MAIN_SOURCE = $(SOURCES_DIR)/SGFPlayerScreensaver.swift

# Output
BUNDLE_DIR = $(BUILD_DIR)/$(PRODUCT_NAME).saver
EXECUTABLE = $(BUNDLE_DIR)/Contents/MacOS/$(PRODUCT_NAME)
INFO_PLIST = $(BUNDLE_DIR)/Contents/Info.plist

# Compiler flags
SWIFT_FLAGS = -target x86_64-apple-macos$(DEPLOYMENT_TARGET) \
              -swift-version $(SWIFT_VERSION) \
              -O \
              -module-name $(PRODUCT_NAME) \
              -emit-library \
              -framework ScreenSaver \
              -framework Cocoa \
              -framework CoreGraphics \
              -framework Foundation

.PHONY: all clean install help

all: $(EXECUTABLE)

$(EXECUTABLE): $(SWIFT_SOURCES) | $(BUNDLE_DIR)/Contents/MacOS
	@echo "🔨 Building $(PRODUCT_NAME) for macOS Sequoia..."
	@swiftc $(SWIFT_FLAGS) -o $@ $(SWIFT_SOURCES)
	@echo "✅ Build complete: $@"

$(BUNDLE_DIR)/Contents/MacOS:
	@echo "📁 Creating bundle structure..."
	@mkdir -p $@
	@mkdir -p $(BUNDLE_DIR)/Contents/Resources

$(INFO_PLIST): Info.plist | $(BUNDLE_DIR)/Contents
	@echo "📋 Copying Info.plist..."
	@cp Info.plist $@
	@plutil -replace CFBundleIdentifier -string $(BUNDLE_IDENTIFIER) $@
	@plutil -replace CFBundleName -string $(PRODUCT_NAME) $@

clean:
	@echo "🧹 Cleaning build directory..."
	@rm -rf $(BUILD_DIR)

install: $(EXECUTABLE) $(INFO_PLIST)
	@echo "📦 Installing screensaver..."
	@echo "⚠️  Note: On Sequoia v15.5, you may need to:"
	@echo "   1. Right-click the .saver file and choose 'Open'"
	@echo "   2. Go to System Settings > Privacy & Security"
	@echo "   3. Click 'Open Anyway' if prompted"
	@echo "   4. The screensaver will appear in Wallpaper settings"
	@cp -R $(BUNDLE_DIR) ~/Library/Screen\ Savers/
	@echo "✅ Installed to ~/Library/Screen Savers/$(PRODUCT_NAME).saver"
	@echo "🖥️  Access via: System Settings > Wallpaper > Screen Saver"

help:
	@echo "SGFPlayerScreensaver Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build the screensaver bundle"
	@echo "  clean     - Remove build artifacts"
	@echo "  install   - Install to user's screen savers directory"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "macOS Sequoia v15.5 Notes:"
	@echo "  - Screensaver preferences are now in Wallpaper settings"
	@echo "  - May require 'Open Anyway' in Privacy & Security"
	@echo "  - Third-party screensavers face increased restrictions"

# Development targets
dev-build: clean all
	@echo "🚀 Development build complete"

dev-install: dev-build install
	@echo "🎯 Development install complete"

# Check for required tools
check-deps:
	@echo "🔍 Checking dependencies..."
	@which swiftc > /dev/null || (echo "❌ Swift compiler not found" && exit 1)
	@which plutil > /dev/null || (echo "❌ plutil not found" && exit 1)
	@test -d $(SCREENSAVER_FRAMEWORK) || (echo "❌ ScreenSaver framework not found" && exit 1)
	@echo "✅ All dependencies found"