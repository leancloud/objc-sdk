Pod::Spec.new do |s|
  s.name     = 'LeanCloudObjc'
  s.version  = '0.0.1-alpha.2'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'LeanCloud Objective-C SDK'
  s.authors  = 'LeanCloud'
  s.license  = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE'
  }
  s.source = {
    :git => "https://github.com/leancloud/objc-sdk.git",
    :tag => "#{s.version}"
  }

  s.ios.deployment_target     = '9.0'
  s.osx.deployment_target     = '10.10'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target    = '9.0'

  s.default_subspec = 'Realtime'

  s.subspec 'Foundation' do |ss|
    ss.source_files =
      'AVOS/LeanCloudObjc/Foundation.h',
      'AVOS/AVOSCloud/**/*.{h,m}'
    
    ss.public_header_files =
      'AVOS/LeanCloudObjc/Foundation.h',
      'AVOS/AVOSCloud/Captcha/LCCaptcha.h',
      'AVOS/AVOSCloud/Utils/LCDynamicObject.h',
      'AVOS/AVOSCloud/SMS/LCSMS.h',
      'AVOS/AVOSCloud/ACL/LCACL.h',
      'AVOS/AVOSCloud/ACL/LCRole.h',
      'AVOS/AVOSCloud/Object/LCSaveOption.h',
      'AVOS/AVOSCloud/LCConstants.h',
      'AVOS/AVOSCloud/LCApplication.h',
      'AVOS/AVOSCloud/CloudCode/LCCloud.h',
      'AVOS/AVOSCloud/File/LCFile.h',
      'AVOS/AVOSCloud/Geo/LCGeoPoint.h',
      'AVOS/AVOSCloud/Object/LCObject+Subclass.h',
      'AVOS/AVOSCloud/Object/LCObject.h',
      'AVOS/AVOSCloud/Object/LCRelation.h',
      'AVOS/AVOSCloud/Object/LCSubclassing.h',
      'AVOS/AVOSCloud/Push/LCInstallation.h',
      'AVOS/AVOSCloud/File/LCFileQuery.h',
      'AVOS/AVOSCloud/Push/LCPush.h',
      'AVOS/AVOSCloud/Query/LCCloudQueryResult.h',
      'AVOS/AVOSCloud/Query/LCQuery.h',
      'AVOS/AVOSCloud/Search/LCSearchQuery.h',
      'AVOS/AVOSCloud/Search/LCSearchSortBuilder.h',
      'AVOS/AVOSCloud/Status/LCStatus.h',
      'AVOS/AVOSCloud/User/LCUser.h',
      'AVOS/AVOSCloud/Utils/LCLogger.h',
      'AVOS/AVOSCloud/Router/LCRouter.h',
      'AVOS/AVOSCloud/LCAvailability.h'

    ss.library =
      'sqlite3'
  end

  s.subspec 'Protobuf+Protocol' do |ss|
    ss.requires_arc = false

    ss.source_files =
      'AVOS/AVOSCloudIM/Protobuf/*.{h,m}',
      'AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}'
  end

  s.subspec 'Realtime' do |ss|
    ss.ios.deployment_target = '9.0'
    ss.osx.deployment_target = '10.10'

    ss.dependency 'LeanCloudObjc/Foundation', "#{s.version}"
    ss.dependency 'LeanCloudObjc/Protobuf+Protocol', "#{s.version}"

    ss.source_files =
      'AVOS/LeanCloudObjc/Realtime.h',
      'AVOS/AVOSCloudIM/**/*.{h,m,c}',
      'AVOS/AVOSCloudLiveQuery/**/*.{h,m}'

    ss.public_header_files =
      'AVOS/LeanCloudObjc/Realtime.h',
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
      'AVOS/AVOSCloudLiveQuery/LCLiveQuery.h'

    ss.exclude_files =
      'AVOS/AVOSCloudIM/Protobuf/*.{h,m}',
      'AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}'
  end
end
