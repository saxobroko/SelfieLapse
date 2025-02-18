//
//  CameraManagerTests.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//


import XCTest
@testable import TimeLens

final class CameraManagerTests: XCTestCase {
    var sut: CameraManager!
    
    override func setUp() {
        super.setUp()
        sut = CameraManager()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testCameraInitialization() {
        XCTAssertNotNil(sut, "CameraManager should be initialized")
        XCTAssertTrue(sut.isReady, "Camera should be ready after initialization")
    }
    
    func testCapturePhoto() async {
        let expectation = XCTestExpectation(description: "Photo capture")
        
        await sut.capturePhoto { image in
            XCTAssertNotNil(image, "Captured image should not be nil")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}