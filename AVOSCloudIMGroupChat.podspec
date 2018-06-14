Pod::Spec.new do |s|
  s.name     = 'AVOSCloudIMGroupChat'
  s.version  = '11.1.0'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'Group Chat Extension of LeanCloud IM Objective-C SDK'
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

  s.requires_arc = true

  s.source_files =
    'AVOS/AVOSCloudIMGroupChat/AVIMReadReceiptMessage.h',
    'AVOS/AVOSCloudIMGroupChat/AVOSCloudIMGroupChat.h',
    'AVOS/AVOSCloudIMGroupChat/AVIMConversation+GroupChat.h',
    'AVOS/AVOSCloudIMGroupChat/AVIMReadReceiptMessage.m',
    'AVOS/AVOSCloudIMGroupChat/AVIMConversation+GroupChat.m'

  s.public_header_files =
    'AVOS/AVOSCloudIMGroupChat/AVIMReadReceiptMessage.h',
    'AVOS/AVOSCloudIMGroupChat/AVOSCloudIMGroupChat.h',
    'AVOS/AVOSCloudIMGroupChat/AVIMConversation+GroupChat.h'

  s.preserve_paths =
   'AVOS/AVOSCloudIM/Protobuf/google'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/AVOSCloudIM/AVOS/AVOSCloudIM/Protobuf"'
  }

  s.dependency 'AVOSCloudIM', "#{s.version}"
end
