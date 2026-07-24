#include "PHTVCoreContracts.h"

#include <stdio.h>

int main(void) {
    if (phtv_core_abi_version() != PHTV_CORE_ABI_VERSION) {
        fputs("unexpected ABI version\n", stderr);
        return 1;
    }

    if ((phtv_core_capabilities() & PHTV_CORE_CAPABILITY_SESSION_ABI) == 0) {
        fputs("session capability is missing\n", stderr);
        return 2;
    }

    if ((phtv_core_capabilities() & PHTV_CORE_CAPABILITY_VIETNAMESE_ENGINE) !=
        PHTV_CORE_CAPABILITY_VIETNAMESE_ENGINE) {
        fputs("Vietnamese engine capabilities are missing\n", stderr);
        return 3;
    }

    if (phtv_core_key_event_size() != sizeof(phtv_core_key_event_t) ||
        phtv_core_input_context_size() != sizeof(phtv_core_input_context_t) ||
        phtv_core_edit_plan_size() != sizeof(phtv_core_edit_plan_t)) {
        fputs("Swift and C disagree on an ABI struct size\n", stderr);
        return 4;
    }

    phtv_core_session_t session = NULL;
    if (phtv_core_session_create(&session) != PHTV_CORE_STATUS_OK || session == NULL) {
        fputs("could not create a session\n", stderr);
        return 5;
    }

    phtv_core_key_event_t event = {0};
    event.struct_size = (uint32_t)sizeof(event);
    event.kind = PHTV_CORE_EVENT_KEY_DOWN;
    event.hardware_key = 0x04;
    event.logical_scalar = (uint32_t)'a';

    phtv_core_input_context_t context = {0};
    context.struct_size = (uint32_t)sizeof(context);
    context.language_mode = PHTV_CORE_LANGUAGE_VIETNAMESE;
    context.app_rule = PHTV_CORE_APP_RULE_INHERIT;
    context.input_method = PHTV_CORE_INPUT_TELEX;
    context.flags = PHTV_CORE_CONTEXT_SUPPORTS_COMPOSITION;

    phtv_core_edit_plan_t plan = {0};
    plan.struct_size = (uint32_t)sizeof(plan);

    phtv_core_status_t status = phtv_core_session_handle_event(
        session,
        &event,
        &context,
        &plan,
        NULL,
        0
    );
    if (status != PHTV_CORE_STATUS_OK ||
        plan.action != PHTV_CORE_EDIT_PASS_THROUGH ||
        plan.session_generation == 0) {
        fputs("unexpected edit plan\n", stderr);
        phtv_core_session_destroy(session);
        return 6;
    }

    if (phtv_core_session_reset(session) != PHTV_CORE_STATUS_OK) {
        fputs("could not reset session\n", stderr);
        phtv_core_session_destroy(session);
        return 7;
    }

    plan.struct_size = (uint32_t)sizeof(plan);
    status = phtv_core_session_handle_event(
        session,
        &event,
        &context,
        &plan,
        NULL,
        0
    );
    if (status != PHTV_CORE_STATUS_OK || plan.session_generation < 2) {
        fputs("session generation did not advance\n", stderr);
        phtv_core_session_destroy(session);
        return 8;
    }

    if (phtv_core_session_reset(session) != PHTV_CORE_STATUS_OK) {
        fputs("could not reset before Telex smoke test\n", stderr);
        phtv_core_session_destroy(session);
        return 9;
    }

    event.logical_scalar = (uint32_t)'d';
    plan.struct_size = (uint32_t)sizeof(plan);
    status = phtv_core_session_handle_event(
        session,
        &event,
        &context,
        &plan,
        NULL,
        0
    );
    if (status != PHTV_CORE_STATUS_OK ||
        plan.action != PHTV_CORE_EDIT_PASS_THROUGH) {
        fputs("first Telex d should pass through\n", stderr);
        phtv_core_session_destroy(session);
        return 10;
    }

    uint16_t replacement[8] = {0};
    plan.struct_size = (uint32_t)sizeof(plan);
    status = phtv_core_session_handle_event(
        session,
        &event,
        &context,
        &plan,
        replacement,
        sizeof(replacement) / sizeof(replacement[0])
    );
    if (status != PHTV_CORE_STATUS_OK ||
        plan.action != PHTV_CORE_EDIT_REPLACE ||
        plan.delete_before_utf16 != 1 ||
        plan.replacement_length_utf16 != 1 ||
        replacement[0] != UINT16_C(0x0111)) {
        fputs("Telex dd did not produce U+0111\n", stderr);
        phtv_core_session_destroy(session);
        return 11;
    }

    if (phtv_core_session_destroy(session) != PHTV_CORE_STATUS_OK) {
        fputs("could not destroy session\n", stderr);
        return 12;
    }

    puts("PHTVCore C ABI smoke test passed");
    return 0;
}
