#!/usr/bin/env ruby
# Podspec automation script
#
# Created by Tang Tianyong on 06/28/16.
# Copyright (c) 2016 LeanCloud Inc. All rights reserved.

require 'clactive'
require 'fileutils'
require 'mustache'
require 'xcodeproj'

module Podspec
  class Generator
    attr_reader :version
    attr_reader :project
    attr_reader :targets
    attr_reader :output_path

    PROJECT_PATH = 'AVOS/AVOS.xcodeproj'

    def initialize(version, output_path = nil)
      @version     = version
      @project     = Xcodeproj::Project.open(PROJECT_PATH)
      @output_path = output_path
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

      header_paths = header_files.map { |pathname|
        relative_path(pathname)
      }

      header_paths
    end

    # Return all public header files of a target.
    def public_header_files(target_name)
      header_files(target_name) do |file|
        settings = file.settings
        settings && settings['ATTRIBUTES'].include?('Public')
      end
    end

    # Return all public source files for a target.
    def source_files(target_name, &filter)
      target = target(target_name)

      source_files = target.source_build_phase.files
      source_files = source_files.select(&filter) unless filter.nil?

      source_paths = source_files.map { |pathname|
        relative_path(pathname)
      }

      source_paths
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
      paths  = pathnames.map { |pathname| "'#{pathname.to_s}'" }
      paths.join(",\n#{spaces}")
    end

    # Write content to file.
    # If `output_path` specified, file will be written to that path,
    # otherwise, file will be written to `filename`.
    def write(filename, content)
      abort 'File name not found.' if filename.nil?
      path = filename

      unless output_path.nil?
        abort "Invalid output directory: #{output_path}" unless File.directory?(output_path)
        path = File.join(output_path, filename)
      end

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

      template = File.read('Podspec/AVOSCloud.podspec.mustache')

      podspec = Mustache.render template, {
        'version'               => version,
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
      no_arc_files        = [Pathname.new('AVOS/AVOSCloudIM/Protobuf/*.{h,m}'), Pathname.new('AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}')]
      public_header_files = public_header_files('AVOSCloudIM-iOS')

      template = File.read('Podspec/AVOSCloudIM.podspec.mustache')

      podspec = Mustache.render template, {
        'version' => version,
        '_ARC' => {
          'source_files' => file_list_string(header_files + source_files, 6),
          'public_header_files' => file_list_string(public_header_files, 6),
          'exclude_files' => file_list_string(no_arc_files, 6)
        }
      }

      write 'AVOSCloudIM.podspec', podspec
    end

    # Generate crash reporting podspec.
    def generateAVOSCloudCrashReporting()
      header_files = header_files('AVOSCloudCrashReporting-iOS')
      source_files = source_files('AVOSCloudCrashReporting-iOS')

      arc_files           = arc_files('AVOSCloudCrashReporting-iOS')
      non_arc_files       = header_files + source_files - arc_files
      public_header_files = public_header_files('AVOSCloudCrashReporting-iOS')

      header_search_paths = [
        '"${PODS_ROOT}/AVOSCloudCrashReporting/Breakpad/src"',
        '"${PODS_ROOT}/AVOSCloudCrashReporting/Breakpad/src/client/apple/Framework"',
        '"${PODS_ROOT}/AVOSCloudCrashReporting/Breakpad/src/common/mac"'
      ].join(' ')

      template = File.read('Podspec/AVOSCloudCrashReporting.podspec.mustache')

      podspec = Mustache.render template, {
        'version' => version,
        '_ARC' => {
          'source_files' => file_list_string(arc_files, 6),
        },
        '_NOARC' => {
          'source_files'   => file_list_string(non_arc_files, 6),
          'public_header_files' => file_list_string(public_header_files, 6),
          'preserve_paths' => "'Breakpad'",
          'pod_target_xcconfig' => "{'HEADER_SEARCH_PATHS' => '#{header_search_paths}'}"
        }
      }

      write 'AVOSCloudCrashReporting.podspec', podspec
    end

    def generate()
      generateAVOSCloud
      generateAVOSCloudIM
      generateAVOSCloudCrashReporting
    end
  end
end

def execute_command(command, exit_on_error = true)
  output = `#{command}`
  exitstatus = $?.exitstatus

  if exitstatus != 0 && exit_on_error
    $stderr.puts "Following command exits with status #{exitstatus}:"
    $stderr.puts command
    exit 1
  end

  output
end

CLActive do
  subcmd :create do
    option :version, '-v v', '--version=version', 'Pod version'
    action do |opt|
      abort 'Version number not found.' if version?.nil?
      abort 'Version number is invalid.' unless Gem::Version.correct? version?

      generator = Podspec::Generator.new(version?)
      generator.generate
    end
  end

  subcmd :push do
    action do |opt|
      pusher = Podspec::Pusher.new('.')
      pusher.push
    end
  end
end
