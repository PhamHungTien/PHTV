//
//  LoginItemService.swift
//  PHTV
//
//  Centralized ServiceManagement wrapper for Launch at Login.
//

import Foundation
import ServiceManagement

private let loginItemErrorDomain = "SMAppServiceErrorDomain"

@MainActor
final class LoginItemService {
    static let shared = LoginItemService()

    enum SetResult {
        case enabled
        case disabled
        case requiresApproval
        case failed(NSError)
    }

    private init() {}

    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    func setEnabled(_ enabled: Bool) -> SetResult {
        enabled ? enable() : disable()
    }

    func openSystemLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func enable() -> SetResult {
        let service = SMAppService.mainApp

        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            break
        @unknown default:
            break
        }

        do {
            try service.register()
        } catch {
            return handleEnableError(error as NSError, service: service)
        }

        return mapEnableStatus(service.status)
    }

    private func disable() -> SetResult {
        let service = SMAppService.mainApp

        switch service.status {
        case .notRegistered, .notFound:
            return .disabled
        case .enabled, .requiresApproval:
            break
        @unknown default:
            break
        }

        do {
            try service.unregister()
            return .disabled
        } catch {
            let nsError = error as NSError
            if nsError.domain == loginItemErrorDomain, nsError.code == Int(kSMErrorJobNotFound) {
                return .disabled
            }
            return .failed(nsError)
        }
    }

    private func handleEnableError(_ error: NSError, service: SMAppService) -> SetResult {
        guard error.domain == loginItemErrorDomain else {
            return .failed(error)
        }

        switch error.code {
        case Int(kSMErrorAlreadyRegistered):
            return mapEnableStatus(service.status)
        case Int(kSMErrorLaunchDeniedByUser):
            return .requiresApproval
        default:
            if service.status == .requiresApproval {
                return .requiresApproval
            }
            return .failed(error)
        }
    }

    private func mapEnableStatus(_ status: SMAppService.Status) -> SetResult {
        switch status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            let error = NSError(
                domain: loginItemErrorDomain,
                code: Int(kSMErrorInternalFailure),
                userInfo: [
                    NSLocalizedDescriptionKey: "Service registration did not reach enabled state."
                ]
            )
            return .failed(error)
        @unknown default:
            let error = NSError(
                domain: loginItemErrorDomain,
                code: Int(kSMErrorInternalFailure),
                userInfo: [
                    NSLocalizedDescriptionKey: "Unknown SMAppService status returned by the system."
                ]
            )
            return .failed(error)
        }
    }
}
