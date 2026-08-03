import Foundation
import JinjaHA
import XCTest

final class APITemplateRendererTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.handler = nil
    }

    func testSuccessfulRenderDecodesJSONString() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
            XCTAssertTrue(request.url?.path.hasSuffix("/api/template") == true)
            let body = #" "Hello from HA" "#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }

        let session = makeMockSession()
        let renderer = HAAPITemplateRenderer(
            baseURL: URL(string: "https://ha.example")!,
            token: "secret-token",
            session: session
        )
        let output = try await renderer.render("{{ states('light.x') }}")
        XCTAssertEqual(output, "Hello from HA")
    }

    func testUnauthorized() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let renderer = HAAPITemplateRenderer(
            baseURL: URL(string: "https://ha.example")!,
            token: "bad",
            session: makeMockSession()
        )
        do {
            _ = try await renderer.render("x")
            XCTFail("Expected unauthorized")
        } catch let error as HATemplateError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testFallbackRendererUsesSecondary() async throws {
        struct Primary: TemplateRendering {
            func render(_ template: String) async throws -> String {
                throw HATemplateError.unsupported("nope")
            }
        }
        struct Secondary: TemplateRendering {
            func render(_ template: String) async throws -> String { "fallback:\(template)" }
        }
        let renderer = FallbackTemplateRenderer(primary: Primary(), fallback: Secondary())
        let output = try await renderer.render("abc")
        XCTAssertEqual(output, "fallback:abc")
    }

    func testTokenNotPresentInAPIErrorMessage() async {
        MockURLProtocol.handler = { request in
            let body = #"token=super-secret-token leaked"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        let renderer = HAAPITemplateRenderer(
            baseURL: URL(string: "https://ha.example")!,
            token: "super-secret-token",
            session: makeMockSession()
        )
        do {
            _ = try await renderer.render("x")
            XCTFail("Expected api error")
        } catch let error as HATemplateError {
            XCTAssertFalse(String(describing: error).contains("super-secret-token"))
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
