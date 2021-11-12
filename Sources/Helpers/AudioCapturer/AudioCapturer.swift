//
//  AudioCapturer.swift
//  SCNRecorder
//
//  Created by Stéphane Copin on 11/12/21.
//

import CoreMedia

protocol AudioCapturer {
	var queue: DispatchQueue? { get }
	var output: ((CMSampleBuffer) -> Void)? { get set }

	func start()
	func stop()

	func canAddOutput(to captureSession: AVCaptureSession) -> Bool
	func addOutput(to captureSession: AVCaptureSession)
	func removeOutput(from captureSession: AVCaptureSession)

	func recommendedAudioSettingsForAssetWriter(
		writingTo outputFileType: AVFileType
	) -> [String: Any]
}
