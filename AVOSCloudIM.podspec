Pod::Spec.new do |s|
  s.name     = 'AVOSCloudIM'
  s.version  = '12.2.0-beta.1'
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
      'AVOS/AVOSCloudIM/Message/AVIMMessageOption.h',
      'AVOS/AVOSCloudIM/Conversation/AVIMKeyedConversation.h',
      'AVOS/AVOSCloudIM/Conversation/AVIMConversationQuery.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMTextMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMRecalledMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMLocationMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMAudioMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMVideoMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMFileMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMTypedMessage.h',
      'AVOS/AVOSCloudIM/TypedMessages/AVIMImageMessage.h',
      'AVOS/AVOSCloudIM/Client/AVIMClient.h',
      'AVOS/AVOSCloudIM/AVIMCommon.h',
      'AVOS/AVOSCloudIM/Conversation/AVIMConversation.h',
      'AVOS/AVOSCloudIM/Message/AVIMMessage.h',
      'AVOS/AVOSCloudIM/Signature/AVIMSignature.h',
      'AVOS/AVOSCloudIM/Client/AVIMClientProtocol.h',
      'AVOS/AVOSCloudIM/Conversation/AVIMConversationMemberInfo.h',
      'AVOS/AVOSCloudIM/Client/AVIMClientInternalConversationManager.h',
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
