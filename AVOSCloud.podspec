Pod::Spec.new do |s|
  s.name     = 'AVOSCloud'
  s.version  = '12.3.3'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'LeanCloud Objective-C SDK'
  s.authors  = 'LeanCloud'
  s.license  = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE'
  }

  s.ios.deployment_target     = '8.0'
  s.osx.deployment_target     = '10.9'
  s.tvos.deployment_target    = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source = {
    :git => "https://github.com/leancloud/objc-sdk.git",
    :tag => "#{s.version}"
  }

  s.source_files =
    'AVOS/AVOSCloud/**/*.{h,m}'

  s.public_header_files =
    'AVOS/AVOSCloud/Captcha/AVCaptcha.h',
    'AVOS/AVOSCloud/Utils/AVDynamicObject.h',
    'AVOS/AVOSCloud/SMS/AVSMS.h',
    'AVOS/AVOSCloud/ACL/LCACL.h',
    'AVOS/AVOSCloud/ACL/AVRole.h',
    'AVOS/AVOSCloud/Object/LCSaveOption.h',
    'AVOS/AVOSCloud/Analytics/AVAnalytics.h',
    'AVOS/AVOSCloud/AVConstants.h',
    'AVOS/AVOSCloud/AVOSCloud.h',
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
    'AVOS/AVOSCloud/User/AVAnonymousUtils.h',
    'AVOS/AVOSCloud/User/AVUser.h',
    'AVOS/AVOSCloud/Utils/AVLogger.h',
    'AVOS/AVOSCloud/Router/LCRouter.h',
    'AVOS/AVOSCloud/AVAvailability.h'

  s.watchos.exclude_files =
    'AVOS/AVOSCloud/Analytics/*.{h,m}'

  s.resources =
    'AVOS/AVOSCloud/AVOSCloud_Art.inc'
    
  s.library =
    'sqlite3'
end
