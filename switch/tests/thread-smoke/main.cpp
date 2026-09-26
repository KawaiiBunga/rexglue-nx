#include <rex/thread.h>

#include <switch.h>

#include <chrono>
#include <cstdio>

using namespace std::chrono_literals;

static void SignalAfterDelay(void* arg) {
  rex::thread::Sleep(20ms);
  static_cast<rex::thread::Event*>(arg)->Set();
}

int main() {
  consoleInit(nullptr);
  padConfigureInput(1, HidNpadStyleSet_NpadStandard);
  PadState pad;
  padInitializeAny(&pad);

  auto manual = rex::thread::Event::CreateManualResetEvent(true);
  bool passed = manual &&
                rex::thread::Wait(manual.get(), false, 0ms) == rex::thread::WaitResult::kSuccess &&
                rex::thread::Wait(manual.get(), false, 0ms) == rex::thread::WaitResult::kSuccess;
  if (manual) {
    manual->Reset();
    passed &= rex::thread::Wait(manual.get(), false, 0ms) ==
              rex::thread::WaitResult::kTimeout;
  }

  auto automatic = rex::thread::Event::CreateAutoResetEvent(false);
  Thread worker{};
  bool worker_started = automatic &&
                        R_SUCCEEDED(threadCreate(&worker, SignalAfterDelay, automatic.get(),
                                                 nullptr, 64 * 1024, 0x2C, -2)) &&
                        R_SUCCEEDED(threadStart(&worker));
  passed &= worker_started;
  if (worker_started) {
    passed &= rex::thread::Wait(automatic.get(), false, 1ms) ==
              rex::thread::WaitResult::kTimeout;
    passed &= rex::thread::Wait(automatic.get(), false, 250ms) ==
              rex::thread::WaitResult::kSuccess;
    passed &= rex::thread::Wait(automatic.get(), false, 0ms) ==
              rex::thread::WaitResult::kTimeout;
    threadWaitForExit(&worker);
    threadClose(&worker);
  }

  std::printf("ReXGlue NX thread smoke: %s\n", passed ? "PASS" : "FAIL");
  std::printf("Thread ID: %u\n", rex::thread::current_thread_system_id());
  std::printf("Press PLUS to exit.\n");
  while (appletMainLoop()) {
    padUpdate(&pad);
    if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
    consoleUpdate(nullptr);
  }
  consoleExit(nullptr);
  return passed ? 0 : 1;
}
