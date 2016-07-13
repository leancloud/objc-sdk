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
      ios_header_files      = header_files('AVOSCloud')
      osx_header_files      = header_files('AVOSCloud-OSX')
      watchos_header_files  = header_files('AVOSCloud-watchOS')

      ios_source_files      = source_files('AVOSCloud')
      osx_source_files      = source_files('AVOSCloud-OSX')
      watchos_source_files  = source_files('AVOSCloud-watchOS')

      public_header_files   = public_header_files('AVOSCloud')
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
      header_files        = header_files('AVOSCloudIM')
      source_files        = source_files('AVOSCloudIM')
      no_arc_files        = [Pathname.new('AVOS/AVOSCloudIM/Protobuf/*.{h,m}'), Pathname.new('AVOS/AVOSCloudIM/Commands/MessagesProtoOrig.pbobjc.{h,m}')]
      public_header_files = public_header_files('AVOSCloudIM')

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
      header_files = header_files('AVOSCloudCrashReporting')
      source_files = source_files('AVOSCloudCrashReporting')

      arc_files           = arc_files('AVOSCloudCrashReporting')
      non_arc_files       = header_files + source_files - arc_files
      public_header_files = public_header_files('AVOSCloudCrashReporting')

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

  class Pusher
    attr_accessor :path

    def initialize(path)
      @path = path
    end

    def log(info)
      info = "====== #{info} ======"
      line = '=' * info.length
      info = "\n#{line}\n#{info}\n#{line}\n"
      puts info
    end

    def make_validation
      abort('Podspec root path not readable, abort!') unless path && File.readable?(path)
      abort('CocoaPods version should be at least 0.39.0!') if Gem::Version.new(`pod --version`.strip) < Gem::Version.new('0.39.0')
    end

    def podspec_version(file)
      content = File.read(file)
      match = content.match(/version(?:\s*)=(?:\s*)("|')(.*)\1/)
      version = match.captures[1] if match && match.captures && match.captures.size == 2
      version
    end

    def podspec_exists?(name, version)
      url = "https://github.com/CocoaPods/Specs/blob/master/Specs/#{name}/#{version}/#{name}.podspec.json"
      http_code = `curl -o /dev/null --silent --head --write-out '%{http_code}' #{url}`
      http_code == '200'
    end

    def push_podspec_in_path(path)
      files = Dir.glob(File.join(path, '**/*.podspec')).uniq.sort do |x, y|
        x = File.basename(x, '.podspec')
        y = File.basename(y, '.podspec')
        x <=> y
      end

      files.each do |file|
        pod_name = File.basename(file, '.podspec')
        pod_version = podspec_version(file)

        if podspec_exists?(pod_name, pod_version)
          log("#{pod_name} #{pod_version} exists!")
          next
        else
          log("#{pod_name} #{pod_version} not exists, try to push it.")
        end

        ok = false

        20.times do
          ok = system("pod trunk push --allow-warnings #{file}")

          if ok
            log("succeed to push #{file}")
            break
          elsif podspec_exists?(pod_name, pod_version)
            ok = true
            break
          else
            log("failed to push #{file}")
          end
        end

        abort('fail to push podspec, please check.') unless ok
      end
    end

    def push
      make_validation
      push_podspec_in_path path
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

  subcmd :deploy do
    action do |opt|
      clean = `git status --porcelain`.empty?
      abort 'Current branch is dirty.' unless clean

      print 'New deployment version: '
      version = STDIN.gets.strip
      abort 'Invalid version number.' unless Gem::Version.correct? version

      print "Are you sure to deploy version #{version} (yes or no): "
      abort 'Canceled.' unless STDIN.gets.strip == 'yes'

      remote_url = 'git@github.com:leancloud/objc-sdk.git'

      tags = execute_command "git ls-remote --tags #{remote_url}"
      abort 'Git tag not found on remote repository. You can push one.' unless tags.include? "refs/tags/#{version}"

      commit_sha = tags[/([0-9a-f]+)\srefs\/tags\/#{version}/, 1]

      temp_remote = "_origin-temp-remote-for-deployment"
      temp_branch = "_branch-temp-branch-for-deployment"

      execute_command "git remote remove #{temp_remote} >/dev/null 2>&1", false
      execute_command "git remote add #{temp_remote} #{remote_url} >/dev/null 2>&1", false
      execute_command "git fetch #{temp_remote} --tags >/dev/null 2>&1"
      execute_command "git checkout -b #{temp_branch} #{commit_sha} >/dev/null 2>&1"

      begin
        user_agent = File.read('AVOS/AVOSCloud/Utils/UserAgent.h')
        user_agent_version = user_agent[/SDK_VERSION @"v(.*?)"/, 1]
        abort "Version mismatched with user agent (#{user_agent_version})." unless version == user_agent_version
      ensure
        execute_command <<-CMD.gsub(/^[ \t]+/, '')
        git checkout - >/dev/null 2>&1
        git branch -D #{temp_branch} >/dev/null 2>&1
        git remote remove #{temp_remote} >/dev/null 2>&1
        CMD
      end

      generator = Podspec::Generator.new(version, 'Podspec')
      generator.generate

      pusher = Podspec::Pusher.new('Podspec')
      pusher.push
    end
  end

  subcmd :push do
    action do |opt|
      pusher = Podspec::Pusher.new('.')
      pusher.push
    end
  end
end
