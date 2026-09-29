ifeq ($(strip $(DEVKITPRO)),)
$(error Set DEVKITPRO to your devkitPro root)
endif

# Keep targets relative: the Windows workspace path may contain spaces.
TARGET := rexglue-nx-smoke
BUILD := build
TOOLBIN := $(DEVKITPRO)/devkitA64/bin
GXX := $(TOOLBIN)/aarch64-none-elf-g++
STRIP := $(TOOLBIN)/aarch64-none-elf-strip
ELF2NRO := $(DEVKITPRO)/tools/bin/elf2nro
NACPTOOL := $(DEVKITPRO)/tools/bin/nacptool
ARCH := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE
CXXFLAGS := -std=gnu++23 -O2 -g -Wall -Wextra -ffunction-sections -fdata-sections $(ARCH) -D__SWITCH__ -I../../include -isystem $(DEVKITPRO)/libnx/include
LDFLAGS := -specs=$(DEVKITPRO)/libnx/switch.specs -Wl,--gc-sections $(ARCH) -L$(DEVKITPRO)/libnx/lib -lnx

.PHONY: all clean
all: $(TARGET).nro

$(BUILD):
	@mkdir -p $(BUILD)

$(BUILD)/main.o: source/main.cpp | $(BUILD)
	$(GXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(TARGET).elf: $(BUILD)/main.o
	$(GXX) $^ -o $@ $(LDFLAGS)

$(TARGET).nacp:
	$(NACPTOOL) --create "ReXGlue NX smoke test" "ReXGlue NX" "0.1.0" $@

$(TARGET).nro: $(TARGET).elf $(TARGET).nacp
	$(STRIP) --strip-all -o $(BUILD)/$(TARGET).stripped $(TARGET).elf
	$(ELF2NRO) $(BUILD)/$(TARGET).stripped $@ --nacp=$(TARGET).nacp

clean:
	rm -f $(BUILD)/main.o $(BUILD)/main.d $(BUILD)/$(TARGET).stripped $(TARGET).elf $(TARGET).nro $(TARGET).nacp

-include $(BUILD)/main.d
