#include <atomic>
#include <new>

#include <objbase.h>
#include <unknwn.h>
#include <windows.h>

#include "Guids.h"
#include "ModuleState.h"
#include "TextService.h"

namespace phtv::windows::ime {
namespace {

class ClassFactory final : public IClassFactory {
public:
    ClassFactory() noexcept {
        module_add_ref();
    }

    HRESULT STDMETHODCALLTYPE QueryInterface(
        const REFIID interface_id,
        void** const object
    ) noexcept override {
        if (object == nullptr) {
            return E_POINTER;
        }
        *object = nullptr;

        if (IsEqualIID(interface_id, IID_IUnknown)
            || IsEqualIID(interface_id, IID_IClassFactory)) {
            *object = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() noexcept override {
        return reference_count_.fetch_add(1, std::memory_order_relaxed) + 1;
    }

    ULONG STDMETHODCALLTYPE Release() noexcept override {
        const ULONG remaining =
            reference_count_.fetch_sub(1, std::memory_order_acq_rel) - 1;
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }

    HRESULT STDMETHODCALLTYPE CreateInstance(
        IUnknown* const outer,
        const REFIID interface_id,
        void** const object
    ) noexcept override {
        if (outer != nullptr) {
            return CLASS_E_NOAGGREGATION;
        }
        return create_text_service(interface_id, object);
    }

    HRESULT STDMETHODCALLTYPE LockServer(const BOOL lock) noexcept override {
        if (lock != FALSE) {
            module_add_ref();
        } else {
            module_release();
        }
        return S_OK;
    }

private:
    ~ClassFactory() noexcept {
        module_release();
    }

    std::atomic<ULONG> reference_count_{1};
};

}  // namespace
}  // namespace phtv::windows::ime

BOOL WINAPI DllMain(
    HINSTANCE instance,
    const DWORD reason,
    LPVOID reserved
) {
    UNREFERENCED_PARAMETER(reserved);

    if (reason == DLL_PROCESS_ATTACH) {
        phtv::windows::ime::module_instance = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}

STDAPI DllCanUnloadNow() {
    return phtv::windows::ime::module_reference_count() == 0
        ? S_OK
        : S_FALSE;
}

STDAPI DllGetClassObject(
    const REFCLSID class_id,
    const REFIID interface_id,
    void** const object
) {
    if (object == nullptr) {
        return E_POINTER;
    }
    *object = nullptr;

    if (!IsEqualCLSID(class_id, phtv::windows::ime::text_service_clsid)) {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    auto* factory =
        new (std::nothrow) phtv::windows::ime::ClassFactory();
    if (factory == nullptr) {
        return E_OUTOFMEMORY;
    }

    const HRESULT result = factory->QueryInterface(interface_id, object);
    factory->Release();
    return result;
}

STDAPI DllRegisterServer() {
    return phtv::windows::ime::register_server();
}

STDAPI DllUnregisterServer() {
    return phtv::windows::ime::unregister_server();
}
