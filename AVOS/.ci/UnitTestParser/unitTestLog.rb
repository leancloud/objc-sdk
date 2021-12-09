#!/usr/bin/ruby
#encoding: utf-8

require 'fileutils'
require 'json'
require_relative 'trollop'
require_relative 'xcresult'

#author: jerrychu
#reference: https://github.com/fastlane-community/trainer/blob/307d52bd6576ceefc40d3f57e34ce3653af10b6b/lib/trainer/test_parser.rb

=begin

 提取单元测试日志文件

 适用于 Xcode 11及以上版本  (https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes?language=objc)

=end

# 解析xcresult文件
def parse_xcresult(path, output_path)
    # 通过xcresulttool获取json数据，json数据中包含了所有单元测试信息
    result_bundle_object_raw = `xcrun xcresulttool get --format json --path #{path}`
    result_bundle_object = JSON.parse(result_bundle_object_raw)

    # 解析出tests_ref中的id，用于获取下一步的数据
    actions_invocation_record = XCResult::ActionsInvocationRecord.new(result_bundle_object)
    diagnostics_refs = actions_invocation_record.actions.map do |action|
      action.action_result.diagnostics_ref
    end.compact
    ids = diagnostics_refs.map(&:id)
    ids.map do |id|
        FileUtils.mkdir_p(output_path)
        dir = "#{output_path}/#{id}"
        `xcrun xcresulttool export --type directory --id #{id} --output-path #{dir}  --path #{path}`
    end
end


if __FILE__ == $0
    opts = Trollop::options do
        opt :xcresult_path, 'Path for xcresult file', :type => :string
        opt :output_path, 'Path for log directory', :type => :string
    end

    Trollop::die :xcresult_path, 'must be provided' if opts[:xcresult_path].nil?

    # 将结果写入到文件中
    output_path = if opts[:output_path].nil? then './unitTestLog' else opts[:output_path] end
    parse_xcresult(opts[:xcresult_path], output_path)

end
