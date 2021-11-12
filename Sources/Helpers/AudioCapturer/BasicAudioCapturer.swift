//
//  BasicAudioCapturer.swift
//  SCNRecorder
//
//  Created by Stéphane Copin on 11/12/21.
//

import Foundation

final class BasicAudioCapturer {
final class AudioInput: NSObject, MediaSession.Input.SampleBufferAudio {
	let queue: DispatchQueue?

	let captureOutput = AVCaptureAudioDataOutput()

	var output: ((CMSampleBuffer) -> Void)?

	init(queue: DispatchQueue) {
		self.queue = queue
		super.init()
		self.captureOutput.setSampleBufferDelegate(self, queue: queue)
	}

	func start() { started = true }

	func stop() { started = false }

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
