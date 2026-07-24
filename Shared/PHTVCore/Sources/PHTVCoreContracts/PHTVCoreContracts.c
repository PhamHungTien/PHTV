#include "PHTVCoreContracts.h"

_Static_assert(sizeof(uint16_t) == 2, "PHTVCore requires 16-bit UTF-16 units");
_Static_assert(sizeof(uint32_t) == 4, "PHTVCore requires 32-bit integers");
_Static_assert(sizeof(uint64_t) == 8, "PHTVCore requires 64-bit integers");
_Static_assert(sizeof(phtv_core_key_event_t) == 28, "Unexpected key event ABI layout");
_Static_assert(sizeof(phtv_core_input_context_t) == 48, "Unexpected input context ABI layout");
_Static_assert(sizeof(phtv_core_edit_plan_t) == 56, "Unexpected edit plan ABI layout");
_Static_assert(offsetof(phtv_core_input_context_t, flags) == 16, "Unexpected context flags offset");
_Static_assert(offsetof(phtv_core_edit_plan_t, flags) == 24, "Unexpected edit flags offset");
