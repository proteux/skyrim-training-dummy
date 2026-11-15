#pragma once

namespace tdui::game {
    using VmResult = std::function<void(const RE::BSScript::Variable&)>;

    class CallbackFunctor final : public RE::BSScript::IStackCallbackFunctor {
    public:
        explicit CallbackFunctor(VmResult cb) : cb_(std::move(cb)) {}
        void operator()(RE::BSScript::Variable result) override {
            if (cb_) {
                cb_(result);
            }
        }
        void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}

    private:
        VmResult cb_;
    };

    RE::BSScript::Internal::VirtualMachine* VM();
    RE::VMHandle HandleFor(RE::TESForm* form);
    void DispatchFailed(const char* className, const char* fn, const VmResult& cb);

    template <class... Args>
    bool CallMethod(RE::TESForm* form, const char* className, const char* fn, VmResult cb, Args&&... args) {
        auto* vm = VM();
        const auto handle = HandleFor(form);
        if (vm && handle != 0) {
            auto* fargs = RE::MakeFunctionArguments(std::decay_t<Args>(std::forward<Args>(args))...);
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> functor(new CallbackFunctor(cb));
            if (vm->DispatchMethodCall(handle, className, fn, fargs, functor)) {
                return true;
            }
        }
        DispatchFailed(className, fn, cb);
        return false;
    }
}
