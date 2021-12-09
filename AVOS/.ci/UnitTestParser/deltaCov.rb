#!/usr/bin/ruby
#encoding: utf-8

require 'fileutils'
require 'json'
require 'ostruct'
require_relative 'trollop'
require_relative 'utils/diffParser.rb'

#author: jerrychu

=begin

 解析diff文件，获取新增或修改的代码文件及行数，并统计新增代码覆盖率
 适用于 Xcode 11  (https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes?language=objc)

=end

# 通过diff结果统计出文件行数修改信息，key为文件路径，value为文件修改的行数列表
def code_change_map(diff_file)
    include GitUtil
    return GitUtil.code_diff_map(diff_file)
end

# 获取每个修改文件的代码覆盖率（新增可执行代码行数和新增被覆盖的可执行代码行数）
def line_coverage_map(file_path, modified_lines, xcresult_path) 
    puts xcresult_path
    `xcrun xccov view --archive --file #{file_path} #{xcresult_path} > result.txt`

    # key为行数，value为该行被单元测试执行的次数（为0表示该行没有被覆盖）
    cov_map = {}
    File.open('result.txt').each do |line|
        array = line.strip.split('[').first.split(':')
        if array.length == 2
            cov_map[array[0].to_i] = array[1].strip
        end
    end

    modified_line_count = 0  # 增加的可执行代码行数
    covered_line_count = 0   # 单元测试覆盖的可执行代码行数

    modified_lines.each { |line| 
        if cov_map[line] and cov_map[line] != '*'
            modified_line_count += 1
            covered_line_count += 1 if cov_map[line].to_i > 0
        end
    }

    puts '------'
    puts file_path
    puts cov_map
    puts modified_line_count, covered_line_count

    return modified_line_count, covered_line_count
end


if __FILE__ == $0
    opts = Trollop::options do
        opt :xcresult_path, 'Path for xcresult file', :type => :string
        opt :proj_dir, 'Path for proj dir', :type => :string
        opt :diff_file, '`git diff` generated file', :type => :string
        opt :output_file, 'Path for result file', :type => :string
    end

    Trollop::die :xcresult_path, 'must be provided' if opts[:xcresult_path].nil?
    Trollop::die :proj_dir, 'must be provided' if opts[:proj_dir].nil?
    Trollop::die :diff_file, 'must be provided' if opts[:diff_file].nil?
    result_path = if opts[:output_file].nil? then 'deltaCov.txt' else opts[:output_file] end
    output = File.new(result_path, "w+")

    modified_line_count = 0  # 增加的可执行代码行数
    covered_line_count = 0   # 单元测试覆盖的可执行代码行数

    file_map = code_change_map(opts[:diff_file])
    file_map.each { |key, value|
        if key and not key.empty? 
            full_path = File.join(opts[:proj_dir], key.strip)
            modified_cout, covered_count = line_coverage_map(full_path, value, opts[:xcresult_path])
            modified_line_count += modified_cout
            covered_line_count += covered_count
        end
    }

    cov_delta = if modified_line_count == 0 then 0 else covered_line_count * 1.0 / modified_line_count end
    puts "新增代码覆盖率：" + cov_delta.round(2).to_s
    output.puts cov_delta

    puts "新增可执行代码行数：" + modified_line_count.to_s
    output.puts modified_line_count

    puts "被覆盖的新增可执行代码行数：" + covered_line_count.to_s
    output.puts covered_line_count
end