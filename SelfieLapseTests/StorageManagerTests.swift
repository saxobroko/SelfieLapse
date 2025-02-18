//
//  StorageManagerTests.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//


import XCTest
@testable import TimeLens

final class StorageManagerTests: XCTestCase {
    var sut: StorageManager!
    
    override func setUp() {
        super.setUp()
        sut = StorageManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testSaveAndLoadImage() throws {
        // Create a test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.red.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        guard let testImage = UIGraphicsGetImageFromCurrentImageContext() else {
            XCTFail("Could not create test image")
            return
        }
        UIGraphicsEndImageContext()
        
        // Test saving
        try sut.saveImage(testImage, withName: "test_image")
        
        // Test loading
        let loadedImage = try sut.loadImage(named: "test_image")
        XCTAssertNotNil(loadedImage, "Loaded image should not be nil")
    }
}