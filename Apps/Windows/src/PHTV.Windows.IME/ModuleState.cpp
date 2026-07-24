#include "ModuleState.h"

#include <atomic>

namespace phtv::windows::ime {
namespace {

std::atomic<long> references{0};

}  // namespace

HINSTANCE module_instance{};

void module_add_ref() noexcept {
    references.fetch_add(1, std::memory_order_relaxed);
}

void module_release() noexcept {
    references.fetch_sub(1, std::memory_order_release);
}

long module_reference_count() noexcept {
    return references.load(std::memory_order_acquire);
}

}  // namespace phtv::windows::ime
