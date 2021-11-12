//
//  BasicAudioCapturer.swift
//  SCNRecorder
//
//  Created by Stéphane Copin on 11/12/21.
//

import AVFoundation
import CoreMedia

final class BasicSampleBufferAudio: NSObject, MediaSession.Input.SampleBufferAudio {
	var output: ((CMSampleBuffer) -> Void)?

	private let captureOutput = AVCaptureAudioDataOutput()
	private let queue: DispatchQueue?

	private var started = false

	init(queue: DispatchQueue) {
		self.queue = queue
		super.init()
		self.captureOutput.setSampleBufferDelegate(self, queue: queue)
	}

	func start() {
		self.started = true
	}

	func stop() {
		self.started = false
	}

	func canAddOutput(to captureSession: AVCaptureSession) -> Bool {
		captureSession.canAddOutput(self.captureOutput)
	}

	func addOutput(to captureSession: AVCaptureSession) {
		captureSession.addOutput(self.captureOutput)
	}

	func removeOutput(from captureSession: AVCaptureSession) {
		captureSession.removeOutput(self.captureOutput)
	}

	func recommendedAudioSettingsForAssetWriter(
		writingTo outputFileType: AVFileType
	) -> [String : Any] {
		captureOutput.recommendedAudioSettingsForAssetWriter(
			writingTo: outputFileType
		) as? [String: Any] ?? AudioSettings().outputSettings
	}
}

extension BasicSampleBufferAudio: AVCaptureAudioDataOutputSampleBufferDelegate {
	@objc func captureOutput(
		_ output: AVCaptureOutput,
		didOutput sampleBuffer: CMSampleBuffer,
		from connection: AVCaptureConnection
	) {
		guard started else { return }
		self.output?(sampleBuffer.delayed(byInterval: self.audioDelay) ?? sampleBuffer)
	}
}

extension BasicSampleBufferAudio: ARSessionObserver {
	func session(
		_ session: ARSession,
		didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer
	) {
		guard started else { return }
		queue.async { [output] in output?(audioSampleBuffer.delayed(byInterval: self.audioDelay) ?? audioSampleBuffer) }
	}
}
