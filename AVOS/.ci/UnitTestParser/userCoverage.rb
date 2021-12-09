#!/usr/bin/ruby
#encoding: utf-8

require 'fileutils'
require_relative 'trollop'

=begin

 获取项目成员的代码覆盖率数据
 适用于 Xcode 11及以上版本  (https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes?language=objc)

=end

# 要统计的开发者列表
$developer_list = ["jerrychu"]

class User
    attr_accessor :name, :file_list, :line_map

    def initialize(name)
        self.name = name # 名称
        self.file_list = [] # 该用户增加/修改的文件列表 
        self.line_map = {} # 该用户增加/修改的所有行，key为文件名，value为该文件中被增加/修改的行数列表
    end

    def to_s 
        desc = name + "\n------\n"
        line_map.each do |key, value|
            desc += key + "\n" + value.to_s + "\n\n"
        end
        desc += "\n\n"
        return desc
    end
end

# 单元测试覆盖数据
def line_coverage_map(file_path, modified_lines, xcresult_path) 
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
    # puts cov_map
    puts modified_line_count, covered_line_count

    return modified_line_count, covered_line_count
end

# 根据git blame统计begin_date到end_date时间内每个人修改过的文件及行数
def user_files_map(proj_dir, begin_date, end_date)
    # key为开发者名称，value为User对象）
    user_map = {}
    all_file = Dir.glob(File.join(proj_dir, "/**/*.[m|.mm]"))
    all_file.each do |file|
        line_map = {}
        content = `git blame -c --date=short #{file}`
        content.each_line do |string|
            string.gsub!(/[^a-zA-Z0-9\-@.]/, " ")
            array = string.split(" ")[1..3]

            username = array[0]
            date = array[1]
            line = array[2]

            if $developer_list.include?(username) and date >= begin_date and date <= end_date
                user_map[username] = User.new(username) if !user_map[username]
                user = user_map[username]
                user.file_list.push(file) if not user.file_list.include?(file)

                user.line_map[file] = [] if !user.line_map[file]
                user.line_map[file].push(line.to_i)
            end
        end
    end
    return user_map
end

if __FILE__ == $0

    opts = Trollop::options do
        opt :xcresult_path, 'Path for xcresult file', :type => :string
        opt :proj_dir, 'Path for proj dir', :type => :string
        opt :begin_date, "Begin date fot collecting blame data(e.g. 2019-10-30)", :type => :string
        opt :end_date, "End date fot collecting blame data(e.g. 2019-10-31)", :type => :string
        opt :output_file, 'Path for result file (html format)', :type => :string
        opt :rawdata_file, 'Path for raw data file(plain text format)', :type => :string
    end

    Trollop::die :xcresult_path, 'must be provided' if opts[:xcresult_path].nil?
    Trollop::die :proj_dir, 'must be provided' if opts[:proj_dir].nil?
    result_path = if opts[:output_file].nil? then 'userCov.html' else opts[:output_file] end
    rawdata_path = if opts[:rawdata_file].nil? then 'rawData.txt' else opts[:rawdata_file] end
    begin_date = if opts[:begin_date].nil? then Time.at(0).strftime("%Y-%m-%d") else opts[:begin_date] end
    end_date = if opts[:end_date].nil? then Time.new.strftime("%Y-%m-%d") else opts[:end_date] end

    output = File.new(result_path, "w+")
    rawDataOutput = File.new(rawdata_path, "w+")

    xcresult_path = opts[:xcresult_path] # 覆盖率文件路径

    output.puts '<html>'
    output.puts '<table style="text-align: center;">'
    output.puts "<caption>代码覆盖率（from #{begin_date} to #{end_date}）</caption>"
    output.puts '<tr>'
    output.puts '<th>开发者</th>' + '<th>增加/修改代码行数</th>' + '<th>覆盖代码行数</th>' + '<th>覆盖率</th>'
    output.puts '<tr/>'

    user_map = user_files_map(opts[:proj_dir], begin_date, end_date)
    user_map.each do |_, user|
        rawDataOutput.puts(user)
    end

    user_map.each do |name, user| 
        modified_line_count = 0  # 增加的可执行代码行数
        covered_line_count = 0   # 单元测试覆盖的可执行代码行数 

        user.line_map.each do |file_name, lines|
            modified_cout, covered_count = line_coverage_map(file_name, lines, xcresult_path)
            modified_line_count += modified_cout
            covered_line_count += covered_count
        end

        coverage = if modified_line_count == 0 then 0 else covered_line_count * 1.0 / modified_line_count end
        output.puts '<tr>'
        output.puts "<td>#{name}</td>" + "<td>#{modified_line_count}</td>" + "<td>#{covered_line_count}</td>" + "<td>#{coverage.round(2)}</td>"
        output.puts '<tr>'
    end

end