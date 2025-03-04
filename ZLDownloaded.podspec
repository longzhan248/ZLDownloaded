
Pod::Spec.new do |s|
  s.name             = 'ZLDownloaded'
  s.version          = '1.0.1'
  s.swift_version    = '5.0'
  s.summary          = 'ZLDownloaded is a download framework.'


  s.homepage         = 'https://github.com/longzhan248'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'longzhan248' => 'longzhan248@qq.com' }
  s.source           = { :git => 'https://github.com/longzhan248/ZLDownloaded.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.subspec 'NewDownload' do |p|
    p.source_files   = 'NewDownload/**/*.{h,m,c,cpp,mm,swift}'
  end

  s.subspec 'NewDownloadOCBridge' do |p|
    p.source_files   = 'NewDownloadOCBridge/*.{h,m,c,cpp,mm,swift}'
  end

  s.requires_arc = true
  s.frameworks = 'CFNetwork'

end
