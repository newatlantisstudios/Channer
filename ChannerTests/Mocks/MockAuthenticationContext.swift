//
//  MockAuthenticationContext.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation
import LocalAuthentication

/// Mock implementation of LAContext for testing FaceID/TouchID authentication
class MockAuthenticationContext: LAContext {

    // MARK: - Mock Configuration

    /// Simulate authentication success/failure
    var shouldSucceed: Bool = true

    /// Error to return on failure
    var authenticationError: Error?

    /// Simulate biometric availability
    var biometricsAvailable: Bool = true

    /// Type of biometry available
    var mockBiometryType: LABiometryType = .faceID

    /// Delay before returning authentication result
    var authenticationDelay: TimeInterval = 0

    // MARK: - Tracking

    private(set) var evaluatePolicyCallCount: Int = 0
    private(set) var canEvaluatePolicyCallCount: Int = 0
    private(set) var lastLocalizedReason: String?
    private(set) var lastPolicy: LAPolicy?

    // MARK: - LAContext Overrides

    override var biometryType: LABiometryType {
        return mockBiometryType
    }

    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        canEvaluatePolicyCallCount += 1
        lastPolicy = policy

        if !biometricsAvailable {
            if let errorPointer = error {
                let err = NSError(
                    domain: LAErrorDomain,
                    code: LAError.biometryNotAvailable.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Biometry is not available"]
                )
                errorPointer.pointee = err
            }
            return false
        }

        return true
    }

    override func evaluatePolicy(
        _ policy: LAPolicy,
        localizedReason: String,
        reply: @escaping (Bool, Error?) -> Void
    ) {
        evaluatePolicyCallCount += 1
        lastLocalizedReason = localizedReason
        lastPolicy = policy

        // Simulate authentication
        if authenticationDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + authenticationDelay) {
                self.performAuthentication(reply: reply)
            }
        } else {
            performAuthentication(reply: reply)
        }
    }

    private func performAuthentication(reply: @escaping (Bool, Error?) -> Void) {
        if shouldSucceed {
            reply(true, nil)
        } else {
            let error = authenticationError ?? LAError(.authenticationFailed)
            reply(false, error)
        }
    }

    // MARK: - Test Helpers

    /// Reset all state and counters
    func reset() {
        evaluatePolicyCallCount = 0
        canEvaluatePolicyCallCount = 0
        lastLocalizedReason = nil
        lastPolicy = nil
        shouldSucceed = true
        authenticationError = nil
        biometricsAvailable = true
        mockBiometryType = .faceID
        authenticationDelay = 0
    }

    /// Simulate different error scenarios
    enum AuthenticationErrorType {
        case authenticationFailed
        case userCancel
        case userFallback
        case biometryNotAvailable
        case biometryNotEnrolled
        case biometryLockout
        case passcodeNotSet
        case systemCancel

        var error: LAError {
            switch self {
            case .authenticationFailed:
                return LAError(.authenticationFailed)
            case .userCancel:
                return LAError(.userCancel)
            case .userFallback:
                return LAError(.userFallback)
            case .biometryNotAvailable:
                return LAError(.biometryNotAvailable)
            case .biometryNotEnrolled:
                return LAError(.biometryNotEnrolled)
            case .biometryLockout:
                return LAError(.biometryLockout)
            case .passcodeNotSet:
                return LAError(.passcodeNotSet)
            case .systemCancel:
                return LAError(.systemCancel)
            }
        }
    }

    /// Configure mock to simulate specific error
    func simulateError(_ errorType: AuthenticationErrorType) {
        shouldSucceed = false
        authenticationError = errorType.error
    }

    /// Simulate FaceID
    func simulateFaceID() {
        mockBiometryType = .faceID
        biometricsAvailable = true
    }

    /// Simulate TouchID
    func simulateTouchID() {
        mockBiometryType = .touchID
        biometricsAvailable = true
    }

    /// Simulate no biometrics
    func simulateNoBiometrics() {
        mockBiometryType = .none
        biometricsAvailable = false
    }

    /// Verify that authentication was attempted
    func didAttemptAuthentication(with reason: String? = nil) -> Bool {
        if let expectedReason = reason {
            return lastLocalizedReason == expectedReason && evaluatePolicyCallCount > 0
        }
        return evaluatePolicyCallCount > 0
    }

    /// Verify that policy can be evaluated
    func didCheckPolicyAvailability() -> Bool {
        return canEvaluatePolicyCallCount > 0
    }
}

// MARK: - Test Scenarios

extension MockAuthenticationContext {

    /// Create context for successful authentication
    static func successfulAuth() -> MockAuthenticationContext {
        let context = MockAuthenticationContext()
        context.shouldSucceed = true
        context.biometricsAvailable = true
        return context
    }

    /// Create context for failed authentication
    static func failedAuth() -> MockAuthenticationContext {
        let context = MockAuthenticationContext()
        context.shouldSucceed = false
        context.authenticationError = LAError(.authenticationFailed)
        return context
    }

    /// Create context for user cancelled authentication
    static func userCancelledAuth() -> MockAuthenticationContext {
        let context = MockAuthenticationContext()
        context.shouldSucceed = false
        context.authenticationError = LAError(.userCancel)
        return context
    }

    /// Create context for unavailable biometrics
    static func noBiometricsAvailable() -> MockAuthenticationContext {
        let context = MockAuthenticationContext()
        context.biometricsAvailable = false
        context.mockBiometryType = .none
        return context
    }

    /// Create context for biometry lockout
    static func biometryLockout() -> MockAuthenticationContext {
        let context = MockAuthenticationContext()
        context.shouldSucceed = false
        context.authenticationError = LAError(.biometryLockout)
        return context
    }
}
