Pod::Spec.new do |s|
  s.name             = 'ev_scanner'
  s.version          = '0.1.0'
  s.summary          = 'EisenVault desktop scanner access (ImageCaptureCore).'
  s.description      = 'Scans through the macOS Image Capture framework.'
  s.homepage         = 'https://eisenvault.com'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'EisenVault' => 'support@eisenvault.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.15'
  s.frameworks       = 'ImageCaptureCore'
  s.swift_version    = '5.0'
end
