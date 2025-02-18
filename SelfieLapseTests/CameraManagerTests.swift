import XCTest
@testable import SelfieLapse // Make sure this matches your target name exactly

final class CameraManagerTests: XCTestCase {
    var sut: CameraManager!
    
    override func setUpWithError() throws {
        super.setUp()
        sut = CameraManager()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        super.tearDown()
    }
    
    func testCameraInitialization() throws {
        XCTAssertNotNil(sut, "CameraManager should be initialized")
        XCTAssertTrue(sut.isReady, "Camera should be ready after initialization")
    }
    
    func testCapturePhoto() async throws {
        let expectation = expectation(description: "Photo capture")
        
        await sut.capturePhoto { image in
            XCTAssertNotNil(image, "Captured image should not be nil")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
