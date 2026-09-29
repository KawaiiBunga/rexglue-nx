#include <rex/platform.h>
#include <rex/thread.h>

#include <switch.h>

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdint>
#include <limits>

static_assert(REX_PLATFORM_SWITCH);

namespace rex::thread {

void EnableAffinityConfiguration() {
  // libnx exposes thread affinity directly; no process opt-in is needed.
}

uint32_t current_thread_system_id() {
  u64 id = 0;
  if (R_FAILED(svcGetThreadId(&id, threadGetCurHandle()))) {
    return 0;
  }
  return static_cast<uint32_t>(id ^ (id >> 32));
}

void set_current_thread_name(std::string_view name) {
  // libnx declares pthread_setname_np but does not provide its implementation.
  // Emit the association for early diagnostics until the SD logging sink is up.
  std::fprintf(stderr, "rex: thread %u: %.*s\n", current_thread_system_id(),
               static_cast<int>(name.size()), name.data());
}

void MaybeYield() { svcSleepThread(YieldType_WithoutCoreMigration); }

void SyncMemory() { std::atomic_thread_fence(std::memory_order_seq_cst); }

void Sleep(std::chrono::microseconds duration) {
  if (duration <= std::chrono::microseconds::zero()) {
    MaybeYield();
    return;
  }
  constexpr int64_t kMaxMicros = std::numeric_limits<int64_t>::max() / 1000;
  int64_t remaining = duration.count();
  while (remaining > 0) {
    const int64_t chunk = std::min(remaining, kMaxMicros);
    svcSleepThread(chunk * 1000);
    remaining -= chunk;
  }
}

class SwitchEvent final : public Event {
 public:
  SwitchEvent(bool manual_reset, bool initial_state) {
    ueventCreate(&event_, !manual_reset);
    if (initial_state) {
      ueventSignal(&event_);
    }
  }

  void* native_handle() const override { return const_cast<UEvent*>(&event_); }
  void Set() override { ueventSignal(&event_); }
  void Reset() override { ueventClear(&event_); }
  void Pulse() override {
    Set();
    Sleep(std::chrono::microseconds(10));
    Reset();
  }

 private:
  UEvent event_{};
};

std::unique_ptr<Event> Event::CreateManualResetEvent(bool initial_state) {
  return std::make_unique<SwitchEvent>(true, initial_state);
}

std::unique_ptr<Event> Event::CreateAutoResetEvent(bool initial_state) {
  return std::make_unique<SwitchEvent>(false, initial_state);
}

WaitResult Wait(WaitHandle* wait_handle, bool is_alertable,
                std::chrono::milliseconds timeout) {
  // APC dispatch is required for alertable waits and is not wired yet.
  if (is_alertable) {
    std::fprintf(stderr, "rex: alertable Switch event wait is not implemented\n");
    return WaitResult::kFailed;
  }
  auto* event = dynamic_cast<SwitchEvent*>(wait_handle);
  if (!event) {
    return WaitResult::kFailed;
  }
  const u64 nanoseconds = timeout == std::chrono::milliseconds::max()
                              ? UINT64_MAX
                              : static_cast<u64>(std::max<int64_t>(0, timeout.count())) * 1000000;
  const Result result =
      waitSingle(waiterForUEvent(static_cast<UEvent*>(event->native_handle())), nanoseconds);
  if (R_SUCCEEDED(result)) {
    return WaitResult::kSuccess;
  }
  if (result == KERNELRESULT(TimedOut) ||
      result == MAKERESULT(Module_Libnx, LibnxError_Timeout)) {
    return WaitResult::kTimeout;
  }
  std::fprintf(stderr, "rex: Switch event wait failed: 0x%x\n", result);
  return WaitResult::kFailed;
}

}  // namespace rex::thread
