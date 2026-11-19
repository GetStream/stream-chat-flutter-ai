## Upcoming

✅ Added

- `AIOnDeviceModel` — the language model built into the device as an `AILocalModel`: Gemini Nano on
  Android through ML Kit's GenAI Prompt API, and Apple's Foundation Models on iOS 26 and macOS 26.
  It fits the conversation to the model's context, streams the whole answer so far and stops when
  the subscription is cancelled.
- `AIOnDeviceModel.status()` and `AIOnDeviceStatus` (`unavailable`, `downloadable`, `downloading`,
  `available`) — where the model is on this device.
- `AIOnDeviceModel.download()` and `AIOnDeviceDownload` (`AIOnDeviceDownloadStarted`,
  `AIOnDeviceDownloadProgress`, `AIOnDeviceDownloadCompleted`, `AIOnDeviceDownloadFailed`) — download
  Gemini Nano when the device can run it but doesn't have it yet.
- `AIOnDeviceError` — the platform's own error code and message, set as an
  `AILocalModelException.cause`. Failures are told apart into `unavailable` (busy, out of quota, in
  the background, assets missing), `contextExceeded` and `failed`.
