#!/usr/bin/env ruby

require 'tmpdir'
require 'fileutils'
require 'clactive'
require './podspec.rb'

class DocGen
  attr_reader :version
  attr_reader :output_path

  def initialize(version, output_path = nil)
    @version     = version
    @output_path = output_path
  end

  def generate
    Dir.mktmpdir do |tmpdir|
      generator = Podspec::Generator.new(version)

      headers = generator.public_header_files('AVOSCloud-iOS') +
                generator.public_header_files('AVOSCloudIM-iOS')

      headers.each { |header| FileUtils.cp header, tmpdir }

      outputdir = output_path || 'appledoc'

      command = <<-EOC.gsub(/^\s*/, '').gsub("\n", ' ')
        appledoc -h
        -v #{version}
        -o #{output_path}
        --company-id "LeanCloud"
        --project-company "LeanCloud, Inc."
        --project-name "LeanCloud Objective-C SDK"
        --keep-undocumented-objects
        --keep-undocumented-members
        --include AVOS/AVConstants.html
        --no-install-docset
        --no-create-docset
        #{tmpdir}
      EOC

      system(command)
    end
  end
end

CLActive do
  subcmd :create do
    option :version, '-v v', '--version=version', 'Pod version'
    option :output,  '-o o', '--output=output',   'Output directory'
    action do |opt|
      abort 'Version number not found.' if version?.nil?
      abort 'Version number is invalid.' unless Gem::Version.correct? version?

      abort 'Output directory not found.' if output?.nil?

      generator = DocGen.new(version?, output?)
      generator.generate
    end
  end
end
