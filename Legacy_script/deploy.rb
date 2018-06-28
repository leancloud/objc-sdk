#!/usr/bin/env ruby
# SDK deployment script
#
# Created by Tang Tianyong on 07/14/16.
# Copyright (c) 2015 LeanCloud Inc. All rights reserved.

require 'clactive'
require './podspec.rb'
require './build-doc.rb'

module Podspec
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
      return `pod trunk info #{name}` =~ /^\s*- #{version}/
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
          ok = system("pod repo update && pod trunk push --allow-warnings #{file}")

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
  subcmd :deploy do
    action do |opt|
      clean = `git status --porcelain`.empty?
      abort 'Current branch is dirty.' unless clean

      print 'New deployment version: '
      version = STDIN.gets.strip
      abort 'Invalid version number.' unless Gem::Version.correct? version

      print 'API docs repository: '
      api_docs_repo = STDIN.gets.strip
      abort 'API docs repository not found.' unless File.directory? api_docs_repo

      api_doc_output = File.join(api_docs_repo, 'api', 'iOS')
      abort 'API doc output path not found.' unless File.directory? api_doc_output

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

        generator = Podspec::Generator.new(version, 'Podspec')
        generator.generate

        pusher = Podspec::Pusher.new('Podspec')
        pusher.push

        Dir.mktmpdir do |tmpdir|
          tmp_output = File.join tmpdir

          docgen = DocGen.new(version, tmp_output)
          docgen.generate

          FileUtils.rm_rf api_doc_output
          FileUtils.cp_r  File.join(tmp_output, 'html'), api_doc_output

          Dir.chdir api_docs_repo do
            command = <<-EOC
            git add -A api/iOS/
            git commit -m "Update iOS API doc for version #{version}"
            git push origin master
            EOC

            system command
          end
        end
      ensure
        execute_command <<-CMD.gsub(/^[ \t]+/, '')
        git checkout - >/dev/null 2>&1
        git branch -D #{temp_branch} >/dev/null 2>&1
        git remote remove #{temp_remote} >/dev/null 2>&1
        CMD
      end
    end
  end
end
