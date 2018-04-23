Pod::Spec.new do |s|
  s.name     = 'AVOSCloud'
  s.version  = '10.2.0'
  s.homepage = 'https://leancloud.cn/'
  s.summary  = 'LeanCloud Objective-C SDK'
  s.authors  = 'LeanCloud'
  s.license  = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE'
  }

  s.platform = :ios, :osx, :tvos, :watchos

  s.ios.deployment_target     = '7.0'
  s.osx.deployment_target     = '10.9'
  s.tvos.deployment_target    = '9.0'
  s.watchos.deployment_target = '2.0'

  s.requires_arc = true

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
    'AVOS/AVOSCloud/ACL/AVACL.h',
    'AVOS/AVOSCloud/ACL/AVRole.h',
    'AVOS/AVOSCloud/Object/AVSaveOption.h',
    'AVOS/AVOSCloud/Analytics/AVAnalytics.h',
    'AVOS/AVOSCloud/AVConstants.h',
    'AVOS/AVOSCloud/AVOSCloud.h',
    'AVOS/AVOSCloud/CloudCode/AVCloud.h',
    'AVOS/AVOSCloud/File/AVFile.h',
    'AVOS/AVOSCloud/Geo/AVGeoPoint.h',
    'AVOS/AVOSCloud/Object/AVObject+Subclass.h',
    'AVOS/AVOSCloud/Object/AVObject.h',
    'AVOS/AVOSCloud/Object/AVRelation.h',
    'AVOS/AVOSCloud/Object/AVSubclassing.h',
    'AVOS/AVOSCloud/Push/AVInstallation.h',
    'AVOS/AVOSCloud/File/AVFileQuery.h',
    'AVOS/AVOSCloud/Push/AVPush.h',
    'AVOS/AVOSCloud/Query/AVCloudQueryResult.h',
    'AVOS/AVOSCloud/Query/AVQuery.h',
    'AVOS/AVOSCloud/Search/AVSearchQuery.h',
    'AVOS/AVOSCloud/Search/AVSearchSortBuilder.h',
    'AVOS/AVOSCloud/Status/AVStatus.h',
    'AVOS/AVOSCloud/User/AVAnonymousUtils.h',
    'AVOS/AVOSCloud/User/AVUser.h',
    'AVOS/AVOSCloud/Utils/AVLogger.h',
    'AVOS/AVOSCloud/AVAvailability.h',
    'AVOS/AVOSCloud/Router/LCRouter.h'

  s.osx.exclude_files =
        []

  s.watchos.exclude_files =
    'AVOS/AVOSCloud/Analytics/AVAnalytics.h',
    'AVOS/AVOSCloud/Analytics/AVAnalyticsImpl.h',
    'AVOS/AVOSCloud/Analytics/AVExceptionHandler.h',
    'AVOS/AVOSCloud/Analytics/AVAnalyticsSession.h',
    'AVOS/AVOSCloud/Utils/AVReachability.h',
    'AVOS/AVOSCloud/Analytics/AVAnalytics_Internal.h',
    'AVOS/AVOSCloud/Analytics/AVAnalyticsActivity.h',
    'AVOS/AVOSCloud/Analytics/AVAnalyticsSession.m',
    'AVOS/AVOSCloud/Analytics/AVAnalyticsImpl.m',
    'AVOS/AVOSCloud/Analytics/AVAnalyticsActivity.m',
    'AVOS/AVOSCloud/Analytics/AVExceptionHandler.m',
    'AVOS/AVOSCloud/Utils/AVReachability.m',
    'AVOS/AVOSCloud/Analytics/AVAnalytics.m'

  s.resources =
    'AVOS/AVOSCloud/AVOSCloud_Art.inc'

  s.xcconfig = {'OTHER_LDFLAGS' => '-ObjC'}

  s.ios.frameworks =
    'CFNetwork',
    'CoreGraphics',
    'CoreLocation',
    'CoreTelephony',
    'MobileCoreServices',
    'QuartzCore',
    'Security',
    'SystemConfiguration'

  s.osx.frameworks =
    'CoreLocation',
    'CoreServices',
    'SystemConfiguration'

  s.tvos.frameworks =
    'CFNetwork',
    'CoreGraphics',
    'CoreLocation',
    'MobileCoreServices',
    'QuartzCore',
    'Security'

  s.watchos.frameworks =
    'CoreGraphics',
    'CoreLocation',
    'MobileCoreServices',
    'Security'

  s.libraries =
    'icucore',
    'sqlite3',
    'z'
end
