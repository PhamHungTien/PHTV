#include <cstdlib>
#include <iostream>
#include <string_view>

#include "CoreBridge.h"

namespace core = phtv::windows::core;

namespace {

[[nodiscard]] bool expect(
    const bool condition,
    const std::string_view message
) {
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
    }
    return condition;
}

[[nodiscard]] bool feed(
    core::Session& session,
    const std::u32string_view keys,
    const core::InputContext& context,
    core::EditPlan& last_plan
) {
    for (const char32_t scalar : keys) {
        const core::KeyEvent event{
            .kind = core::EventKind::key_down,
            .hardware_usage = 0,
            .logical_scalar = scalar,
        };
        if (session.handle(event, context, last_plan) != core::Status::ok) {
            return false;
        }
    }
    return true;
}

}  // namespace

int main() {
    bool passed = true;
    core::Session session;

    passed &= expect(
        session.initialize() == core::Status::ok,
        "Core bridge initializes with ABI v1"
    );

    core::InputContext telex_context;
    core::EditPlan plan;
    passed &= expect(
        feed(session, U"dd", telex_context, plan),
        "Telex events cross the native bridge"
    );
    passed &= expect(
        plan.action == core::EditAction::replace,
        "Second Telex d creates a replacement plan"
    );
    passed &= expect(plan.replacement == u"đ", "Telex dd renders đ");
    passed &= expect(plan.delete_before_utf16 == 1, "Telex dd replaces one code unit");
    passed &= expect(plan.consumes_key, "Replacement consumes the command key");

    passed &= expect(session.reset() == core::Status::ok, "Session resets");

    core::InputContext vni_context;
    vni_context.input_method = core::InputMethod::vni;
    passed &= expect(
        feed(session, U"vie6t5", vni_context, plan),
        "VNI events cross the native bridge"
    );
    passed &= expect(plan.replacement == u"việt", "VNI vie6t5 renders việt");

    passed &= expect(session.reset() == core::Status::ok, "Session resets again");
    core::InputContext locked_context;
    locked_context.application_rule = core::ApplicationRule::lock_english;
    passed &= expect(
        feed(session, U"dd", locked_context, plan),
        "Locked-English events remain valid"
    );
    passed &= expect(
        plan.action == core::EditAction::pass_through,
        "Locked-English context never transforms input"
    );

    if (!passed) {
        return EXIT_FAILURE;
    }

    std::cout << "PHTV Windows Core bridge tests passed\n";
    return EXIT_SUCCESS;
}
