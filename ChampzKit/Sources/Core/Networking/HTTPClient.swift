import Foundation

/// What repositories depend on. Tests stub this with canned JSON; no network.
public protocol HTTPClientProtocol: Sendable {
    func send<R>(_ endpoint: Endpoint<R>) async throws(AppError) -> R
}

/// The one HTTP client. Builds the request, runs the interceptors, maps every failure
/// to `AppError`, decodes with `JSONDecoder.api()`. About the only place in the app
/// that knows what a status code is.
public actor HTTPClient: HTTPClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let decoder: JSONDecoder
    private let maxAttempts = 2

    public init(baseURL: URL, session: URLSession = .shared, interceptors: [any RequestInterceptor] = []) {
        self.baseURL = baseURL
        self.session = session
        self.interceptors = interceptors
        decoder = .api()
    }

    public func send<R>(_ endpoint: Endpoint<R>) async throws(AppError) -> R {
        let context = RequestContext(
            path: endpoint.path,
            requiresAuth: endpoint.requiresAuth,
            idempotencyKey: endpoint.idempotencyKey
        )
        var attempt = 0
        while true {
            var request = try makeRequest(endpoint)
            for interceptor in interceptors {
                request = try await interceptor.prepare(request, context: context)
            }

            let (data, info) = try await perform(request)
            for interceptor in interceptors {
                await interceptor.didReceive(info, body: data, for: request, context: context)
            }

            if (200 ..< 300).contains(info.statusCode) {
                return try decode(R.self, from: data, path: endpoint.path)
            }

            if attempt + 1 < maxAttempts {
                var retry = false
                for interceptor in interceptors where await interceptor.shouldRetry(
                    after: info,
                    context: context,
                    attempt: attempt
                ) {
                    retry = true
                }
                if retry {
                    attempt += 1
                    continue
                }
            }
            throw APIErrorMapper.map(statusCode: info.statusCode, body: data)
        }
    }

    // MARK: - Steps

    private func makeRequest(_ endpoint: Endpoint<some Any>) throws(AppError) -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appending(path: endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw .unknown
        }
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }
        guard let url = components.url else { throw .unknown }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if let key = endpoint.idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws(AppError) -> (Data, ResponseInfo) {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AppError.unknown }
            let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    result[key] = value
                }
            }
            return (data, ResponseInfo(statusCode: http.statusCode, headers: headers, duration: clock.now - start))
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw APIErrorMapper.map(urlError: error)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .unknown
        }
    }

    private func decode<R: Decodable>(_: R.Type, from data: Data, path: String) throws(AppError) -> R {
        if R.self == NoContent.self, let empty = NoContent() as? R {
            return empty
        }
        do {
            return try decoder.decode(R.self, from: data)
        } catch {
            let detail = "\(path): \(Self.describe(error))"
            Log.decoding.error("Strict decode failed — \(detail, privacy: .public)")
            throw .decoding(detail)
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        context.codingPath.map(\.stringValue).joined(separator: ".")
    }

    private static func describe(_ error: any Error) -> String {
        guard let decodingError = error as? DecodingError else { return String(describing: error) }
        switch decodingError {
        case let .keyNotFound(key, context):
            return "missing '\(key.stringValue)' at \(Self.path(context))"
        case let .valueNotFound(type, context):
            return "null \(type) at \(Self.path(context))"
        case let .typeMismatch(type, context):
            return "expected \(type) at \(Self.path(context)): \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "corrupt at \(Self.path(context)): \(context.debugDescription)"
        @unknown default:
            return String(describing: decodingError)
        }
    }
}
