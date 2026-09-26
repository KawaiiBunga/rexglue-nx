#include <rex/assert.h>
#include <rex/chrono/clock.h>
#include <rex/platform.h>

#include <switch/arm/counter.h>
#include <sys/time.h>

static_assert(REX_PLATFORM_SWITCH);

namespace rex::chrono {

uint64_t Clock::host_tick_frequency_platform() { return armGetSystemTickFreq(); }

uint64_t Clock::host_tick_count_platform() { return armGetSystemTick(); }

uint64_t Clock::QueryHostSystemTime() {
  constexpr uint64_t kSeconds1601To1970 = 11644473600ull;
  timeval now{};
  const int error = gettimeofday(&now, nullptr);
  assert_zero(error);
  return (static_cast<uint64_t>(now.tv_sec) + kSeconds1601To1970) * 10000000ull +
         static_cast<uint64_t>(now.tv_usec) * 10;
}

uint64_t Clock::QueryHostUptimeMillis() {
  const uint64_t frequency = host_tick_frequency_platform();
  const uint64_t ticks = host_tick_count_platform();
  return ticks / frequency * 1000 + (ticks % frequency) * 1000 / frequency;
}

}  // namespace rex::chrono
