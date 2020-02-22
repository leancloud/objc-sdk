Pod::Spec.new do |s|
  s.name     = 'AVOSCloudLiveQuery'
  s.version  = '12.1.2'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'LeanCloud LiveQuery Objective-C SDK'
  s.authors  = 'LeanCloud'
  s.license  = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE'
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source = {
    :git => "https://github.com/leancloud/objc-sdk.git",
    :tag => "#{s.version}"
  }

  s.source_files =
    'AVOS/AVOSCloudLiveQuery/**/*.{h,m}'

  s.public_header_files =
    'AVOS/AVOSCloudLiveQuery/AVLiveQuery.h',
    'AVOS/AVOSCloudLiveQuery/AVOSCloudLiveQuery.h'

  s.dependency 'AVOSCloud', "#{s.version}"
  s.dependency 'AVOSCloudIM', "#{s.version}"
end
