#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'stream_chat_flutter_ai_ondevice'
  s.version          = '0.1.0'
  s.summary          = "An on-device fallback model for stream_chat_flutter_ai: Apple's Foundation Models."
  s.description      = <<-DESC
An on-device fallback model for stream_chat_flutter_ai: Apple's Foundation Models on iOS 26 and macOS 26.
                       DESC
  s.homepage         = 'https://github.com/GetStream/stream-chat-flutter-ai'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Stream' => 'support@getstream.io' }
  s.source           = { :path => '.' }
  s.source_files = 'stream_chat_flutter_ai_ondevice/Sources/stream_chat_flutter_ai_ondevice/**/*.swift'
  s.dependency 'FlutterMacOS'
  # Foundation Models exists from iOS and macOS 26; the code checks for it at runtime.
  s.weak_frameworks = 'FoundationModels'

  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
