Pod::Spec.new do |s|
  s.name     = 'AVOSCloudLiveQuery'
  s.version  = '10.2.0'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'LeanCloud LiveQuery Objective-C SDK'
  s.authors  = 'LeanCloud'
  s.license  = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE'
  }

  s.platform = :ios, :osx

  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'

  s.source = {
    :git => "https://github.com/leancloud/objc-sdk.git",
    :tag => "#{s.version}"
  }

  s.source_files =
    'AVOS/AVOSCloudLiveQuery/**/*.{h,m}'

  s.public_header_files =
    'AVOS/AVOSCloudLiveQuery/AVLiveQuery.h',
    'AVOS/AVOSCloudLiveQuery/AVOSCloudLiveQuery.h'

  s.preserve_paths =
   'AVOS/AVOSCloudIM/Protobuf/google'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/AVOSCloudIM/AVOS/AVOSCloudIM/Protobuf"'
  }

  s.dependency 'AVOSCloud', "#{s.version}"
  s.dependency 'AVOSCloudIM', "#{s.version}"
end
