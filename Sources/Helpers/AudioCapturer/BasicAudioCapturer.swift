//
//  BasicAudioCapturer.swift
//  SCNRecorder
//
//  Created by Stéphane Copin on 11/12/21.
//

import CoreMedia

final class BasicAudioCapturer {
final class AudioInput: NSObject, MediaSession.Input.SampleBufferAudio {
	let queue: DispatchQueue?

	var output: ((CMSampleBuffer) -> Void)?6

	private let captureOutput = AVCaptureAudioDataOutput()

	init(queue: DispatchQueue) {
		self.queue = queue
		super.init()
		self.captureOutput.setSampleBufferDelegate(self, queue: queue)
	}

	func start() { started = true }

	func stop() { started = false }

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

extension BaseRecorder.AudioInput: AVCaptureAudioDataOutputSampleBufferDelegate {

	@objc func captureOutput(
		_ output: AVCaptureOutput,
		didOutput sampleBuffer: CMSampleBuffer,
		from connection: AVCaptureConnection
	) {
		guard started else { return }
		self.output?(sampleBuffer.delayed(byInterval: self.audioDelay) ?? sampleBuffer)
	}
}

extension BaseRecorder.AudioInput: ARSessionObserver {

	func session(
		_ session: ARSession,
		didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer
	) {
		guard started else { return }
		queue.async { [output] in output?(audioSampleBuffer.delayed(byInterval: self.audioDelay) ?? audioSampleBuffer) }
	}
}
