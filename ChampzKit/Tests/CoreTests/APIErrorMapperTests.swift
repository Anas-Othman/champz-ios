import Foundation
import Testing
@testable import Core

struct APIErrorMapperTests {
    private func body(_ json: String) -> Data {
        Data(json.utf8)
    }

    private func envelope(code: String, message: String, details: String, errors: String = "[]") -> Data {
        let head = #"{"error": {"code": "\#(code)", "message": "\#(message)", "details": "\#(details)", "#
        return body(head + #""errors": \#(errors), "request_id": "r1"}}"#)
    }

    @Test func statusCodesMapToCases() {
        #expect(APIErrorMapper.map(statusCode: 401, body: Data()) == .unauthorized)
        #expect(APIErrorMapper.map(statusCode: 403, body: Data()) == .forbidden)
        #expect(APIErrorMapper.map(statusCode: 404, body: Data()) == .notFound)
        #expect(APIErrorMapper.map(statusCode: 504, body: Data()) == .timeout)
        #expect(APIErrorMapper.map(statusCode: 500, body: body(#"{"detail": "boom"}"#)) == .server(
            message: "boom",
            code: nil
        ))
    }

    @Test func envelopeDetailsAreThePlayerFacingMessage() {
        let error = APIErrorMapper.map(
            statusCode: 400,
            body: envelope(
                code: "02023",
                message: "Invalid OTP",
                details: "The one-time password is invalid or has expired."
            )
        )
        #expect(error == .server(
            message: "The one-time password is invalid or has expired.",
            code: APIErrorCode.otpInvalid
        ))
    }

    @Test func cooldownCarriesRetryAfterFromTheErrorsList() {
        let error = APIErrorMapper.map(
            statusCode: 429,
            body: envelope(
                code: "02053",
                message: "Code already sent",
                details: "A code was already sent. Try again in 40 seconds.",
                errors: #"[{"field": "retry_after_seconds", "message": "40"}]"#
            )
        )
        #expect(error == .rateLimited(code: APIErrorCode.otpCooldown, retryAfter: 40))
        #expect(APIErrorMapper.map(statusCode: 429, body: Data()) == .rateLimited(code: nil, retryAfter: nil))
    }

    @Test func envelopeFieldErrorsBecomeValidation() {
        let error = APIErrorMapper.map(
            statusCode: 400,
            body: envelope(
                code: "02007",
                message: "Validation error",
                details: "One or more submitted fields are invalid.",
                errors: #"[{"field": "phone", "message": "Enter a valid phone number."}]"#
            )
        )
        #expect(error == .validation([FieldError(field: "phone", message: "Enter a valid phone number.")]))
    }

    @Test func userAlreadyExistsIsAServerErrorWithItsCode() {
        let error = APIErrorMapper.map(
            statusCode: 409,
            body: envelope(
                code: "02022",
                message: "User already exists",
                details: "An account with these details already exists."
            )
        )
        #expect(error.apiCode == APIErrorCode.userAlreadyExists)
    }

    @Test func plainDjangoFieldErrorsStillBecomeValidation() {
        let error = APIErrorMapper.map(
            statusCode: 400,
            body: body(#"{"phone": ["Enter a valid phone number."], "name": "Required"}"#)
        )
        #expect(error == .validation([
            FieldError(field: "name", message: "Required"),
            FieldError(field: "phone", message: "Enter a valid phone number."),
        ]))
    }

    @Test func paymentCodesBecomePaymentFailures() {
        let error = APIErrorMapper.map(
            statusCode: 400,
            body: body(#"{"code": "INSUFFICIENT_FUNDS", "detail": "Balance too low"}"#)
        )
        #expect(error == .payment(.insufficientFunds))
    }

    @Test func urlErrorsMap() {
        #expect(APIErrorMapper.map(urlError: URLError(.notConnectedToInternet)) == .offline)
        #expect(APIErrorMapper.map(urlError: URLError(.timedOut)) == .timeout)
        #expect(APIErrorMapper.map(urlError: URLError(.cancelled)) == .cancelled)
        #expect(APIErrorMapper.map(urlError: URLError(.badServerResponse)) == .unknown)
    }
}
