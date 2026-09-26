#include <cstdio>
#include <rex/platform.h>
#include <switch.h>

static_assert(REX_PLATFORM_SWITCH && REX_ARCH_ARM64);

int main() {
  consoleInit(nullptr);
  padConfigureInput(1, HidNpadStyleSet_NpadStandard);
  PadState pad;
  padInitializeAny(&pad);

  std::printf("ReXGlue NX toolchain smoke test\n");
  std::printf("libnx initialized; ReXGlue is not linked yet.\n");
  std::printf("Press PLUS to exit.\n");

  while (appletMainLoop()) {
    padUpdate(&pad);
    if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
    consoleUpdate(nullptr);
  }

  consoleExit(nullptr);
  return 0;
}
