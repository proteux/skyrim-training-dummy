#include "game/Papyrus.h"

namespace tdui::game {
    RE::BSScript::Internal::VirtualMachine* VM() {
        return RE::BSScript::Internal::VirtualMachine::GetSingleton();
    }

    RE::VMHandle HandleFor(RE::TESForm* form) {
        auto* vm = VM();
        if (!vm || !form) {
            return 0;
        }
        auto* policy = vm->GetObjectHandlePolicy();
        if (!policy) {
            return 0;
        }
        const auto handle = policy->GetHandleForObject(form->GetFormType(), form);
        return handle == policy->EmptyHandle() ? 0 : handle;
    }

    void DispatchFailed(const char* className, const char* fn, const VmResult& cb) {
        logger::warn("Could not call {}.{} (script not loaded or function missing)", className, fn);
        if (cb) {
            cb(RE::BSScript::Variable{});
        }
    }
}
