#!/usr/bin/env ruby

require 'octokit'
require 'json'

def write_orig_file(name, content)
  file = File.open(name, 'w')
  file.puts(Base64.decode64(content))
  file.close
end

def get_file_content(name)
  file = File.open(name, 'rb')
  content = file.read
  file.close
  return content
end

def overwrite(path, content)
  if File.exist?(path)
    file = File.open(path, 'w')
    file.puts(content)
    file.close
    p path + ' updating success.'
  else
    p path + ' not found.'
  end
end

def delete_file(name)
  File.delete(name) if File.exist?(name)
end

GITHUB_PERSONAL_ACCESS_TOKEN = JSON.parse(get_file_content('script_config.json'))['GITHUB_PERSONAL_ACCESS_TOKEN']

def updating

  if !GITHUB_PERSONAL_ACCESS_TOKEN
    p 'GITHUB_PERSONAL_ACCESS_TOKEN not found'
    return
  end

  directory = File.basename(Dir.getwd)

  if directory == 'objc-sdk' && system('protoc --version') == false
    p 'protoc not found.'
    return
  end

  if directory == 'swift-sdk' && system('protoc-gen-swift --version') == false
    p 'protoc-gen-swift not found.'
    return
  end

  client = Octokit::Client.new(access_token: GITHUB_PERSONAL_ACCESS_TOKEN)
  response = client.contents("leancloud/avoscloud-push", :path => 'protobuf-messages/resources/proto/messages2.proto.orig', query: {ref: 'develop'})

  if !response.content
    p response.inspect
    return
  end

  if directory == 'objc-sdk'

    orig_file_name = 'messages.proto.orig'
    write_orig_file(orig_file_name, response.content)

    if system('protoc --objc_out=. ' + orig_file_name)

      system('./subst.tcl')
      objc_file_header_name = 'MessagesProtoOrig.pbobjc.h'
      objc_file_implementation_name = 'MessagesProtoOrig.pbobjc.m'
      objc_file_header_content = get_file_content(objc_file_header_name)
      objc_file_implementation_content = get_file_content(objc_file_implementation_name)
      overwrite('AVOS/AVOSCloudIM/Commands/' + objc_file_header_name, objc_file_header_content)
      overwrite('AVOS/AVOSCloudIM/Commands/' + objc_file_implementation_name, objc_file_implementation_content)
      delete_file(objc_file_header_name)
      delete_file(objc_file_implementation_name)

    else
      p 'protobuf file generating failed.'
    end

    delete_file(orig_file_name)

  elsif directory == 'swift-sdk'

    orig_file_name = 'Command.orig'
    write_orig_file(orig_file_name, response.content)

    if system('protoc --swift_out=. ' + orig_file_name)

      swift_file_name = 'Command.pb.swift'
      swift_file_new_content = get_file_content(swift_file_name)
      swift_file_new_content = swift_file_new_content.gsub('PushServer_Messages2_', 'IM')
      overwrite('Sources/IM/' + swift_file_name, swift_file_new_content)
      delete_file(swift_file_name)

    else
      p 'protobuf file generating failed.'
    end

    delete_file(orig_file_name)

  else
    p 'unknown project.'
  end

end

updating