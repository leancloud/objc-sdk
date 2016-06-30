#!/usr/bin/env ruby
# Podspec file generation script
#
# Created by Tang Tianyong on 06/28/16.
# Copyright (c) 2016 LeanCloud Inc. All rights reserved.

require 'xcodeproj'
require 'mustache'
require 'clactive'

module Podspec

  class Generator
    attr_accessor :version
    attr_accessor :project
    attr_accessor :targets

    PROJECT_PATH = 'AVOS/AVOS.xcodeproj'

    def initialize(version)
      @version = version
      @project = Xcodeproj::Project.open(PROJECT_PATH)
      @targets = project.targets
    end

    def target(name)
      target = targets.find { |target| target.name == name }

      if target.nil?
        raise "The target named #{name} not found."
      end

      return target
    end

    def relative_pathnames(pathnames)
      pathnames.map do |pathname|
        pwd = Pathname.new('.').realpath
        pathname.file_ref.real_path.relative_path_from(pwd)
      end
    end

    def header_files(target_name)
      target = target(target_name)

      header_files = target.headers_build_phase.files

      header_paths = relative_pathnames header_files
      header_paths
    end

    def public_header_files(target_name)
      target = target(target_name)

      header_files = target.headers_build_phase.files.select do |file|
        settings = file.settings
        settings && settings['ATTRIBUTES'].include?('Public')
      end

      header_paths = relative_pathnames header_files
      header_paths
    end

    def source_files(target_name, &filter)
      target = target(target_name)
      source_files = target.source_build_phase.files

      source_files = source_files.select &filter unless filter.nil?
      source_paths = relative_pathnames source_files
      source_paths
    end

    def non_arc_files(target_name)
      source_files(target_name) do |file|
        settings = file.settings
        settings && settings['COMPILER_FLAGS'] == '-fno-objc-arc'
      end
    end

    def arc_files(target_name)
      source_files(target_name) do |file|
        settings = file.settings
        settings && settings['COMPILER_FLAGS'] == '-fobjc-arc'
      end
    end

    def file_list_string(pathnames)
      paths = pathnames.map { |pathname| "'#{pathname.to_s}'" }
      paths.join(",\n    ")
    end

    def read(path)
      File.open(path).read
    end

    def write(path, content)
      File.open(path, 'w') { |file| file.write(content) }
    end

    def generateAVOSCloud()
      ios_headers     = public_header_files('AVOSCloud')
      osx_headers     = public_header_files('AVOSCloud-OSX')
      tvos_headers    = public_header_files('AVOSCloud-tvOS')
      watchos_headers = public_header_files('AVOSCloud-watchOS')

      ios_sources     = source_files('AVOSCloud')
      osx_sources     = source_files('AVOSCloud-OSX')
      tvos_sources    = source_files('AVOSCloud-tvOS')
      watchos_sources = source_files('AVOSCloud-watchOS')

      osx_exclude_files     = (ios_headers - osx_headers) + (ios_sources - osx_sources)
      watchos_exclude_files = (ios_headers - watchos_headers) + (ios_sources - watchos_sources)

      template = read 'AVOSCloud.podspec.mustache'

      podspec = Mustache.render template, {
        'version'               => version,
        'source_files'          => "'AVOS/AVOSCloud/**/*.{h,m,inc}'",
        'public_header_files'   => file_list_string(ios_headers),
        'osx_exclude_files'     => file_list_string(osx_exclude_files),
        'watchos_exclude_files' => file_list_string(watchos_exclude_files)
      }

      write 'AVOSCloud.podspec', podspec
    end

    def generateAVOSCloudIM()
      headers = public_header_files('AVOSCloudIM')
      non_arc_files = non_arc_files('AVOSCloudIM')

      template = read 'AVOSCloudIM.podspec.mustache'

      podspec = Mustache.render template, {
        'version'             => version,
        'source_files'        => "'AVOS/AVOSCloudIM/**/*.{h,c,m}'",
        'public_header_files' => file_list_string(headers),
        'exclude_files'       => "'AVOS/AVOSCloudIM/Protobuf/google'",
        'non_arc_files'       => file_list_string(non_arc_files),
        'preserve_paths'      => "'AVOS/AVOSCloudIM/Protobuf'",
        'xcconfig'            => "{'HEADER_SEARCH_PATHS' => '\"$(PODS_ROOT)/AVOSCloudIM/AVOS/AVOSCloudIM/Protobuf\"'}"
      }

      write 'AVOSCloudIM.podspec', podspec
    end

    def generateAVOSCloudCrashReporting()
      header_files = header_files('AVOSCloudCrashReporting')
      source_files = source_files('AVOSCloudCrashReporting')
      public_header_files = public_header_files('AVOSCloudCrashReporting')
      arc_files = arc_files('AVOSCloudCrashReporting')

      template = read 'AVOSCloudCrashReporting.podspec.mustache'

      podspec = Mustache.render template, {
        'version'             => version,
        'source_files'        => file_list_string(header_files + source_files),
        'public_header_files' => file_list_string(public_header_files),
        'arc_files'           => file_list_string(arc_files)
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
          ok = system("pod trunk push #{file}")

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
