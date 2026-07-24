#pragma once

#include <windows.h>

namespace phtv::windows::ime {

extern HINSTANCE module_instance;

void module_add_ref() noexcept;
void module_release() noexcept;
[[nodiscard]] long module_reference_count() noexcept;

[[nodiscard]] HRESULT register_server() noexcept;
[[nodiscard]] HRESULT unregister_server() noexcept;

}  // namespace phtv::windows::ime
