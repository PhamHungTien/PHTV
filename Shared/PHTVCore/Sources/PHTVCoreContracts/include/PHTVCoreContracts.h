#ifndef PHTV_CORE_CONTRACTS_H
#define PHTV_CORE_CONTRACTS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PHTV_CORE_ABI_VERSION ((uint32_t)1)

typedef int32_t phtv_core_status_t;
enum {
    PHTV_CORE_STATUS_OK = 0,
    PHTV_CORE_STATUS_INVALID_ARGUMENT = 1,
    PHTV_CORE_STATUS_UNSUPPORTED_ABI = 2,
    PHTV_CORE_STATUS_BUFFER_TOO_SMALL = 3,
    PHTV_CORE_STATUS_INTERNAL_ERROR = 4
};

typedef uint64_t phtv_core_capabilities_t;
enum {
    PHTV_CORE_CAPABILITY_SESSION_ABI = UINT64_C(1) << 0,
    PHTV_CORE_CAPABILITY_TELEX_ENGINE = UINT64_C(1) << 1,
    PHTV_CORE_CAPABILITY_VNI_ENGINE = UINT64_C(1) << 2,
    PHTV_CORE_CAPABILITY_VIETNAMESE_ENGINE =
        PHTV_CORE_CAPABILITY_TELEX_ENGINE | PHTV_CORE_CAPABILITY_VNI_ENGINE
};

typedef uint32_t phtv_core_event_kind_t;
enum {
    PHTV_CORE_EVENT_KEY_DOWN = 1,
    PHTV_CORE_EVENT_KEY_UP = 2
};

typedef uint32_t phtv_core_modifier_t;
enum {
    PHTV_CORE_MODIFIER_SHIFT = UINT32_C(1) << 0,
    PHTV_CORE_MODIFIER_CONTROL = UINT32_C(1) << 1,
    PHTV_CORE_MODIFIER_ALT = UINT32_C(1) << 2,
    PHTV_CORE_MODIFIER_COMMAND = UINT32_C(1) << 3,
    PHTV_CORE_MODIFIER_CAPS_LOCK = UINT32_C(1) << 4
};

typedef uint32_t phtv_core_language_mode_t;
enum {
    PHTV_CORE_LANGUAGE_ENGLISH = 0,
    PHTV_CORE_LANGUAGE_VIETNAMESE = 1
};

typedef uint32_t phtv_core_input_method_t;
enum {
    PHTV_CORE_INPUT_TELEX = 0,
    PHTV_CORE_INPUT_VNI = 1
};

typedef uint32_t phtv_core_app_rule_t;
enum {
    PHTV_CORE_APP_RULE_INHERIT = 0,
    PHTV_CORE_APP_RULE_PREFER_ENGLISH = 1,
    PHTV_CORE_APP_RULE_LOCK_ENGLISH = 2
};

typedef uint64_t phtv_core_context_flag_t;
enum {
    PHTV_CORE_CONTEXT_SUPPORTS_COMPOSITION = UINT64_C(1) << 0,
    PHTV_CORE_CONTEXT_SUPPORTS_SURROUNDING_TEXT = UINT64_C(1) << 1,
    PHTV_CORE_CONTEXT_SENSITIVE = UINT64_C(1) << 2,
    PHTV_CORE_CONTEXT_TERMINAL = UINT64_C(1) << 3
};

typedef uint32_t phtv_core_edit_action_t;
enum {
    PHTV_CORE_EDIT_PASS_THROUGH = 0,
    PHTV_CORE_EDIT_REPLACE = 1,
    PHTV_CORE_EDIT_COMMIT = 2,
    PHTV_CORE_EDIT_RESET_SESSION = 3
};

typedef uint64_t phtv_core_edit_flag_t;
enum {
    PHTV_CORE_EDIT_CONSUMES_KEY = UINT64_C(1) << 0,
    PHTV_CORE_EDIT_ENDS_COMPOSITION = UINT64_C(1) << 1
};

/*
 * hardware_key is the USB HID keyboard usage, not a platform virtual-key code.
 * logical_scalar is a Unicode scalar value after the platform layout is applied.
 */
typedef struct phtv_core_key_event {
    uint32_t struct_size;
    phtv_core_event_kind_t kind;
    uint32_t hardware_key;
    uint32_t logical_scalar;
    phtv_core_modifier_t modifiers;
    uint8_t is_repeat;
    uint8_t reserved[7];
} phtv_core_key_event_t;

/*
 * App identity and sensitive field detection remain in the platform adapter.
 * The Core receives only the normalized rule result and capability flags.
 */
typedef struct phtv_core_input_context {
    uint32_t struct_size;
    phtv_core_language_mode_t language_mode;
    phtv_core_app_rule_t app_rule;
    phtv_core_input_method_t input_method;
    phtv_core_context_flag_t flags;
    uint64_t reserved[3];
} phtv_core_input_context_t;

/*
 * replacement_length is measured in UTF-16 code units. The caller owns the
 * replacement buffer and all memory outside the opaque session.
 */
typedef struct phtv_core_edit_plan {
    uint32_t struct_size;
    phtv_core_edit_action_t action;
    uint32_t delete_before_utf16;
    uint32_t delete_after_utf16;
    uint32_t replacement_length_utf16;
    uint32_t reserved0;
    phtv_core_edit_flag_t flags;
    uint64_t session_generation;
    uint64_t reserved[2];
} phtv_core_edit_plan_t;

typedef void *phtv_core_session_t;

uint32_t phtv_core_abi_version(void);
phtv_core_capabilities_t phtv_core_capabilities(void);
size_t phtv_core_key_event_size(void);
size_t phtv_core_input_context_size(void);
size_t phtv_core_edit_plan_size(void);

phtv_core_status_t phtv_core_session_create(
    phtv_core_session_t *out_session
);

phtv_core_status_t phtv_core_session_destroy(
    phtv_core_session_t session
);

phtv_core_status_t phtv_core_session_reset(
    phtv_core_session_t session
);

phtv_core_status_t phtv_core_session_handle_event(
    phtv_core_session_t session,
    const phtv_core_key_event_t *event,
    const phtv_core_input_context_t *context,
    phtv_core_edit_plan_t *out_plan,
    uint16_t *replacement_utf16,
    size_t replacement_capacity_utf16
);

#ifdef __cplusplus
}
#endif

#endif
