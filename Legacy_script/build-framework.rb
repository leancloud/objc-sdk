#!/usr/bin/env ruby
# SDK build script
#
# Created by Tang Tianyong on 12/14/15.
# Copyright (c) 2015 LeanCloud Inc. All rights reserved.

require 'fileutils'
require 'xcodeproj'

class FrameworkBuilder
  CONFIGURATION = 'Release'
  PROJECT_PATH  = 'AVOS/AVOS.xcodeproj'

  def project_path
    @project_path || PROJECT_PATH
  end

  def configuration
    @configuration || CONFIGURATION
  end

  def empty_string?(string)
    string.nil? || string.strip.length == 0
  end

  def project
    @project ||= Xcodeproj::Project.open(project_path)
  end

  # All targets of project.
  def targets
    project.targets
  end

  # Return target for name.
  def target(name)
    target = targets.find { |target| target.name == name }
    abort "The target named #{name} not found." if target.nil?
    return target
  end

  def product_name(target_name)
    target(target_name).product_name
  end

  def build_path
    File.join(File.absolute_path(project_path), 'build')
  end

  def slice_build_path
    "#{build_path}/.slices"
  end

  def execmd(cmd)
    abort("\n>>> Command execution failed:\n>>> #{cmd}\n") unless system(cmd)
  end

  def clean_build_dir
    dir = build_path
    FileUtils.rm_rf(dir) if File.exist?(dir) && dir != '/'
  end

  def clean_target(target_name)
    execmd "xcodebuild -project #{project_path} -target #{target_name} clean"
  end

  def build_target(target_name, sdk, build_dir, archs, misc='')
    command = <<-EOC.strip.gsub(/^[ \t]+/, '')
    xcodebuild \
    -project #{project_path} \
    -target #{target_name} \
    -configuration #{configuration}
    EOC

    command += " -sdk #{sdk}" unless empty_string?(sdk)
    command += " CONFIGURATION_BUILD_DIR=\"#{build_dir}\"" unless empty_string?(build_dir)
    command += " ARCHS=\"#{archs}\"" unless empty_string?(archs)
    command += " #{misc}" unless empty_string?(misc)

    execmd command
  end

  def lipo(output, *inputs)
    execmd "lipo -create -output #{output} #{inputs.join(' ')}"
  end

  def merge_frameworks(prefix, target_name)
    product_name = product_name(target_name)

    frameworks = Dir.glob(File.join(prefix, '**', "#{product_name}.framework"))
    first_framework = frameworks.first

    return if first_framework.nil?

    output = File.join(build_path, "#{target_name}.framework")
    execmd "cp -RLp #{first_framework} #{output}"

    return if frameworks.count == 1

    executables  = frameworks.map { |framework| File.join(framework, product_name) }

    lipo File.join(output, product_name), *executables
  end

  def build_ios_sdk(target_name)
    clean_target target_name

    prefix = File.join(slice_build_path, target_name)

    build_target target_name, 'iphonesimulator', File.join(prefix, 'iphonesimulator'), 'i386 x86_64'
    build_target target_name, 'iphoneos',        File.join(prefix, 'iphoneos'),        'armv7 armv7s arm64', 'OTHER_LDFLAGS="-fembed-bitcode -lz" OTHER_CFLAGS="-fembed-bitcode"'

    merge_frameworks(prefix, target_name)
  end

  def build_watchos_sdk(target_name)
    clean_target target_name

    prefix = File.join(slice_build_path, target_name)

    build_target target_name, 'watchsimulator', File.join(prefix, 'watchsimulator'), 'i386'
    build_target target_name, 'watchos',        File.join(prefix, 'watchos'),        'armv7k', 'OTHER_LDFLAGS="-fembed-bitcode -lz" OTHER_CFLAGS="-fembed-bitcode"'

    merge_frameworks(prefix, target_name)
  end

  def build_tvos_sdk(target_name)
    clean_target target_name

    prefix = File.join(slice_build_path, target_name)

    build_target target_name, 'appletvsimulator', File.join(prefix, 'appletvsimulator'), 'i386 x86_64'
    build_target target_name, 'appletvos',        File.join(prefix, 'appletvos'),        'arm64', 'OTHER_LDFLAGS="-fembed-bitcode -lz" OTHER_CFLAGS="-fembed-bitcode"'

    merge_frameworks(prefix, target_name)
  end

  def build_macos_sdk(target_name)
    clean_target target_name

    prefix = File.join(slice_build_path, target_name)

    build_target target_name, nil, File.join(prefix, 'macos'), 'x86_64'

    merge_frameworks(prefix, target_name)
  end

  def run
    clean_build_dir

    # Build foundation module
    build_ios_sdk     'AVOSCloud-iOS'
    build_macos_sdk   'AVOSCloud-macOS'
    build_tvos_sdk    'AVOSCloud-tvOS'
    build_watchos_sdk 'AVOSCloud-watchOS'

    # Build IM module
    build_ios_sdk     'AVOSCloudIM-iOS'
    build_macos_sdk   'AVOSCloudIM-macOS'

    # Build crash reporting module
    build_ios_sdk     'AVOSCloudCrashReporting-iOS'
  end

end

FrameworkBuilder.new.run
