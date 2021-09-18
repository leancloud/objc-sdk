Pod::Spec.new do |s|
  s.name     = 'LeanCloudObjc'
  s.version  = '13.4.0'
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
      'AVOS/Sources/Foundation/**/*.{h,m}'
    
    ss.public_header_files =
      'AVOS/LeanCloudObjc/Foundation.h',
      'AVOS/Sources/Foundation/Vendor/LCNetworking/LCNetworkReachabilityManager.h',
      'AVOS/Sources/Foundation/Captcha/LCCaptcha.h',
      'AVOS/Sources/Foundation/Utils/LCDynamicObject.h',
      'AVOS/Sources/Foundation/SMS/LCSMS.h',
      'AVOS/Sources/Foundation/Leaderboard/LCLeaderboard.h',
      'AVOS/Sources/Foundation/ACL/LCACL.h',
      'AVOS/Sources/Foundation/ACL/LCRole.h',
      'AVOS/Sources/Foundation/Object/LCSaveOption.h',
      'AVOS/Sources/Foundation/LCApplication.h',
      'AVOS/Sources/Foundation/CloudCode/LCCloud.h',
      'AVOS/Sources/Foundation/File/LCFile.h',
      'AVOS/Sources/Foundation/Geo/LCGeoPoint.h',
      'AVOS/Sources/Foundation/Object/LCObject+Subclass.h',
      'AVOS/Sources/Foundation/Object/LCObject.h',
      'AVOS/Sources/Foundation/Object/LCRelation.h',
      'AVOS/Sources/Foundation/Object/LCSubclassing.h',
      'AVOS/Sources/Foundation/Push/LCInstallation.h',
      'AVOS/Sources/Foundation/File/LCFileQuery.h',
      'AVOS/Sources/Foundation/Push/LCPush.h',
      'AVOS/Sources/Foundation/Query/LCCloudQueryResult.h',
      'AVOS/Sources/Foundation/Query/LCQuery.h',
      'AVOS/Sources/Foundation/Search/LCSearchQuery.h',
      'AVOS/Sources/Foundation/Search/LCSearchSortBuilder.h',
      'AVOS/Sources/Foundation/Status/LCStatus.h',
      'AVOS/Sources/Foundation/User/LCUser.h',
      'AVOS/Sources/Foundation/User/LCFriendship.h',
      'AVOS/Sources/Foundation/Utils/LCLogger.h',
      'AVOS/Sources/Foundation/Utils/LCErrorUtils.h',
      'AVOS/Sources/Foundation/Utils/LCUtils.h'

    ss.library =
      'sqlite3'
  end

  s.subspec 'Protobuf+Protocol' do |ss|
    ss.requires_arc = false

    ss.source_files =
      'AVOS/Sources/Realtime/IM/Protobuf/*.{h,m}',
      'AVOS/Sources/Realtime/IM/Commands/MessagesProtoOrig.pbobjc.{h,m}'
  end

  s.subspec 'Realtime' do |ss|
    ss.ios.deployment_target = '9.0'
    ss.osx.deployment_target = '10.10'

    ss.dependency 'LeanCloudObjc/Foundation', "#{s.version}"
    ss.dependency 'LeanCloudObjc/Protobuf+Protocol', "#{s.version}"

    ss.source_files =
      'AVOS/LeanCloudObjc/Realtime.h',
      'AVOS/Sources/Realtime/IM/**/*.{h,m,c}',
      'AVOS/Sources/Realtime/LiveQuery/**/*.{h,m}'

    ss.public_header_files =
      'AVOS/LeanCloudObjc/Realtime.h',
      'AVOS/Sources/Realtime/IM/Connection/LCRTMWebSocket.h',
      'AVOS/Sources/Realtime/IM/Message/LCIMMessageOption.h',
      'AVOS/Sources/Realtime/IM/Conversation/LCIMKeyedConversation.h',
      'AVOS/Sources/Realtime/IM/Conversation/LCIMConversationQuery.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMTextMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMRecalledMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMLocationMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMAudioMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMVideoMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMFileMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMTypedMessage.h',
      'AVOS/Sources/Realtime/IM/TypedMessages/LCIMImageMessage.h',
      'AVOS/Sources/Realtime/IM/Client/LCIMClient.h',
      'AVOS/Sources/Realtime/IM/LCIMCommon.h',
      'AVOS/Sources/Realtime/IM/Conversation/LCIMConversation.h',
      'AVOS/Sources/Realtime/IM/Message/LCIMMessage.h',
      'AVOS/Sources/Realtime/IM/Signature/LCIMSignature.h',
      'AVOS/Sources/Realtime/IM/Client/LCIMClientProtocol.h',
      'AVOS/Sources/Realtime/IM/Conversation/LCIMConversationMemberInfo.h',
      'AVOS/Sources/Realtime/LiveQuery/LCLiveQuery.h'

    ss.exclude_files =
      'AVOS/Sources/Realtime/IM/Protobuf/*.{h,m}',
      'AVOS/Sources/Realtime/IM/Commands/MessagesProtoOrig.pbobjc.{h,m}'
  end
end
