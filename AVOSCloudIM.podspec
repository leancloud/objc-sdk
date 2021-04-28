Pod::Spec.new do |s|
  s.name     = 'AVOSCloudIM'
  s.version  = '12.3.3'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'LeanCloud IM Objective-C SDK'
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

  s.subspec '_ARC' do |ss|
    ss.dependency 'AVOSCloudIM/_NOARC', "#{s.version}"

    ss.source_files =
      'AVOS/AVOSCloudIM/**/*.{h,m,c}'

    ss.public_header_files =
      'AVOS/AVOSCloudIM/Message/LCIMMessageOption.h',
      'AVOS/AVOSCloudIM/Conversation/LCIMKeyedConversation.h',
      'AVOS/AVOSCloudIM/Conversation/LCIMConversationQuery.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMTextMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMRecalledMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMLocationMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMAudioMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMVideoMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMFileMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMTypedMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/LCIMImageMessage.h',
      'AVOS/AVOSCloudIM/Client/LCIMClient.h',
      'AVOS/AVOSCloudIM/LCIMCommon.h',
      'AVOS/AVOSCloudIM/Conversation/LCIMConversation.h',
      'AVOS/AVOSCloudIM/Message/LCIMMessage.h',
      'AVOS/AVOSCloudIM/Signature/LCIMSignature.h',
      'AVOS/AVOSCloudIM/Client/LCIMClientProtocol.h',
      'AVOS/AVOSCloudIM/Conversation/LCIMConversationMemberInfo.h',
      'AVOS/AVOSCloudIM/Client/LCIMClientInternalConversationManager.h',
      'AVOS/AVOSCloudIM/AVOSCloudIM.h'

    ss.exclude_files =
      'AVOS/AVOSCloudIM/Protobuf/*.{h,m}',
      'AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}'
  end

  s.subspec '_NOARC' do |ss|
    ss.requires_arc = false

    ss.source_files =
      'AVOS/AVOSCloudIM/Protobuf/*.{h,m}',
      'AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}'
  end

  s.dependency 'AVOSCloud', "#{s.version}"
end
