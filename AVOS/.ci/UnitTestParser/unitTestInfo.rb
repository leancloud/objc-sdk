#!/usr/bin/ruby
#encoding: utf-8

require 'fileutils'
require 'json'
require_relative 'trollop'
require_relative 'xcresult'

#author: jerrychu
#reference: https://github.com/fastlane-community/trainer/blob/307d52bd6576ceefc40d3f57e34ce3653af10b6b/lib/trainer/test_parser.rb

=begin

 解析构建产生的info.plist/TestSummaries.plist文件，统计单元测试基本信息。每一行的数据为：
 1. 单元测试用例数
 2. 单元测试失败用例数
 3. 单元测试总时长

 适用于 Xcode 11及以上版本  (https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes?language=objc)

=end

# 解析xcresult文件
def parse_xcresult(path, output)
    # 通过xcresulttool获取json数据，json数据中包含了所有单元测试信息
    result_bundle_object_raw = `xcrun xcresulttool get --format json --path #{path}`
    result_bundle_object = JSON.parse(result_bundle_object_raw)

    # 解析出tests_ref中的id，用于获取下一步的数据
    actions_invocation_record = XCResult::ActionsInvocationRecord.new(result_bundle_object)
    test_refs = actions_invocation_record.actions.map do |action|
      action.action_result.tests_ref
    end.compact
    ids = test_refs.map(&:id)

    # 通过xcresulttool获取id进一步获取每个test summary的信息
    summaries = ids.map do |id|
      raw = `xcrun xcresulttool get --format json --path #{path} --id #{id}`
      json = JSON.parse(raw)
      XCResult::ActionTestPlanRunSummaries.new(json)
    end

    # 失败单元测试数据
    failures = actions_invocation_record.issues.test_failure_summaries || []

    # 进一步解析
    generate_summary_object(summaries, failures, output)
end

# 解析出summary对象数据，便于读取
def generate_summary_object(summaries, failures, output)
    all_summaries = summaries.map(&:summaries).flatten
    testable_summaries = all_summaries.map(&:testable_summaries).flatten

    rows = testable_summaries.map do |testable_summary|
        all_tests = testable_summary.all_tests.flatten
    
        # 统计所有单元测试数据
        test_rows = all_tests.map do |test|
            test_row = {
                identifier: "#{test.parent.name}.#{test.name}",
                name: test.name,
                duration: test.duration,
                status: test.test_status,
                test_group: test.parent.name,
            }

            # 如果单元测试失败，标记一下
            failure = test.find_failure(failures)
            if failure
                test_row[:failures] = [{
                    file_name: "",
                    line_number: 0,
                    message: "",
                    performance_failure: {},
                    failure_message: failure.failure_message
                }]
            end

            test_row
        end

        # 再包装一层
        row = {
            project_path: testable_summary.project_relative_path,
            target_name: testable_summary.target_name,
            test_name: testable_summary.name,
            duration: all_tests.map(&:duration).inject(:+),
            tests: test_rows
        }
        # 计算总用例数、失败用例数
        row[:number_of_tests] = row[:tests].count
        row[:number_of_failures] = row[:tests].find_all { |a| (a[:failures] || []).count > 0 }.count

        row
    end

    # 统计总数并输出
    tests_count = 0
    failures_count = 0
    duration = 0
    puts "单元测试项目："
    rows.each do |row|
        tests_count += row[:number_of_tests]
        failures_count += row[:number_of_failures]
        duration += row[:duration]
        puts "• #{row[:target_name]}"
    end

    puts "单元测试用例总数：#{tests_count} 条" 
    output.puts tests_count

    puts "单元测试用例失败：#{failures_count} 条"
    output.puts failures_count

    duration = duration.round(2)
    puts "单元测试运行时长：#{duration}s"
    output.puts duration
    puts "---------------"

end


if __FILE__ == $0
    opts = Trollop::options do
        opt :xcresult_path, 'Path for xcresult file', :type => :string
        opt :output_file, 'Path for output file', :type => :string
    end

    Trollop::die :xcresult_path, 'must be provided' if opts[:xcresult_path].nil?

    # 将结果写入到文件中
    result_path = if opts[:output_file].nil? then 'unitTestInfo.txt' else opts[:output_file] end
    output = File.new(result_path, "w+")
    parse_xcresult(opts[:xcresult_path], output)

end
