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

	func recommendedAudioSettingsForAssetWriter(
		writingTo outputFileType: AVFileType
	) -> [String: Any]
}
