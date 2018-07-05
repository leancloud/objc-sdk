#!/usr/bin/env ruby

require 'fileutils'
require 'mustache'
require 'xcodeproj'
require 'set'

$version

# Return target for name.
def target(name)
  target = Xcodeproj::Project.open('AVOS/AVOS.xcodeproj').targets.find { |target| target.name == name }
  abort "The target named #{name} not found." if target.nil?
  return target
end

# Return relative path based on current working directory.
def relative_path(pathname)
  pwd = Pathname.new('.').realpath
  pathname.file_ref.real_path.relative_path_from(pwd)
end

# Return all header files of a target.
def header_files(target_name, &filter)
  target = target(target_name)
  header_files = target.headers_build_phase.files
  header_files = header_files.select(&filter) unless filter.nil?
  header_paths = header_files.map { |pathname| relative_path(pathname) }
  header_paths
end

# Return all public source files for a target.
def source_files(target_name, &filter)
  target = target(target_name)
  source_files = target.source_build_phase.files
  source_files = source_files.select(&filter) unless filter.nil?
  source_paths = source_files.map { |pathname| relative_path(pathname) }
  source_paths
end

# Return all public header files of a target.
def public_header_files(target_name)
  header_files(target_name) do |file|
    settings = file.settings
    settings && settings['ATTRIBUTES'].include?('Public')
  end
end

# Check whether a file has compiler flag or not.
def has_compiler_flag(file, flag)
  settings = file.settings
  return false if settings.nil?
  compiler_flags = settings['COMPILER_FLAGS']
  return false if compiler_flags.nil?
  compiler_flags.include? flag
end

# Return all files that have '-fno-objc-arc' flag of a target.
def no_arc_files(target_name)
  source_files(target_name) do |file|
    has_compiler_flag(file, '-fno-objc-arc')
  end
end

# Return all files that have '-fobjc-arc' flag of a target.
def arc_files(target_name)
  source_files(target_name) do |file|
    has_compiler_flag(file, '-fobjc-arc')
  end
end

# Convert pathnames to file list string.
def file_list_string(pathnames, indent)
  spaces = ' ' * indent
  unless pathnames.empty?
    paths  = pathnames.map { |pathname| "'#{pathname.to_s}'" }
    paths.join(",\n#{spaces}")
  else
    spaces += '[]'
  end
end

# Write content to file.
def write(filename, content)
  abort 'File name not found.' if filename.nil?
  path = filename
  File.write(path, content)
end

# Generate foundtion podspec.
def generateAVOSCloud()
  ios_header_files      = header_files('AVOSCloud-iOS')
  osx_header_files      = header_files('AVOSCloud-macOS')
  watchos_header_files  = header_files('AVOSCloud-watchOS')
  ios_source_files      = source_files('AVOSCloud-iOS')
  osx_source_files      = source_files('AVOSCloud-macOS')
  watchos_source_files  = source_files('AVOSCloud-watchOS')
  public_header_files   = public_header_files('AVOSCloud-iOS')
  osx_exclude_files     = (ios_header_files - osx_header_files)     + (ios_source_files - osx_source_files)
  watchos_exclude_files = (ios_header_files - watchos_header_files) + (ios_source_files - watchos_source_files)
  template = File.read('Podspec_mustache/AVOSCloud.podspec.mustache')
  podspec = Mustache.render template, {
    'version'               => $version,
    'source_files'          => "'AVOS/AVOSCloud/**/*.{h,m}'",
    'resources'             => "'AVOS/AVOSCloud/AVOSCloud_Art.inc'",
    'public_header_files'   => file_list_string(public_header_files, 4),
    'osx_exclude_files'     => file_list_string(osx_exclude_files, 4),
    'watchos_exclude_files' => file_list_string(watchos_exclude_files, 4),
    'xcconfig'              => "{'OTHER_LDFLAGS' => '-ObjC'}"
  }
  write 'AVOSCloud.podspec', podspec
end

# Generate IM podspec.
def generateAVOSCloudIM()
  header_files        = header_files('AVOSCloudIM-iOS')
  source_files        = source_files('AVOSCloudIM-iOS')
  no_arc_files        = [
    Pathname.new('AVOS/AVOSCloudIM/Protobuf/*.{h,m}'),
    Pathname.new('AVOS/AVOSCloudIM/Protobuf/google/protobuf/*.{h,m}'),
    Pathname.new('AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}')
  ]
  public_header_files = public_header_files('AVOSCloudIM-iOS')
  template = File.read('Podspec_mustache/AVOSCloudIM.podspec.mustache')
  podspec = Mustache.render template, {
    'version' => $version,
    '_ARC' => {
      'source_files' => file_list_string(header_files + source_files, 6),
      'public_header_files' => file_list_string(public_header_files, 6),
      'exclude_files' => file_list_string(no_arc_files, 6)
    }
  }
  write 'AVOSCloudIM.podspec', podspec
end

# Generate live query podspec.
def generateAVOSCloudLiveQuery()
  header_files = header_files('AVOSCloudLiveQuery-iOS')
  source_files = source_files('AVOSCloudLiveQuery-macOS')
  public_header_files = public_header_files('AVOSCloudLiveQuery-iOS')
  template = File.read('Podspec_mustache/AVOSCloudLiveQuery.podspec.mustache')
  podspec = Mustache.render template, {
    'version' => $version,
    'source_files' => "'AVOS/AVOSCloudLiveQuery/**/*.{h,m}'",
    'public_header_files' => file_list_string(public_header_files, 4)
  }
  write 'AVOSCloudLiveQuery.podspec', podspec
end

$version = ARGV[0]
if $version == 'public_header_files'
  puts public_header_files('AVOSCloud-iOS') + public_header_files('AVOSCloudIM-iOS') + public_header_files('AVOSCloudLiveQuery-iOS')
else
  generateAVOSCloud()
  generateAVOSCloudIM()
  generateAVOSCloudLiveQuery()
  puts 'generate podspec success.'
end
