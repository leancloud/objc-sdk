#!/usr/bin/swift

import Foundation

enum Result {
    case success(Any?)
    case fail(String)
}

let timerQueue: DispatchQueue = DispatchQueue(label: "timerQueue")
var timeoutWorkItem: DispatchWorkItem?
var isTerminating: Bool = false

func script_processor(launchPath: String, arguments: [String]) -> Result {
    
    let task: Process = Process()
    let outputPipe: Pipe = Pipe()
    let errorPipe: Pipe = Pipe()
    task.launchPath = launchPath
    task.arguments = arguments
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    task.launch()
    timeoutWorkItem = DispatchWorkItem {
        isTerminating = true
        task.terminate()
    }
    timerQueue.asyncAfter(
        deadline: .now() + .seconds(600),
        execute: timeoutWorkItem!
    )
    task.waitUntilExit()
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    
    let command_log_string: String = "[\(launchPath) \(arguments.joined(separator: " "))]"
    
    if isTerminating {
        isTerminating = false
        return .fail("❌ command \(command_log_string) timeout.")
    }
    
    let outputString: String = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    if task.terminationStatus == 0 {
        return .success(outputString)
    } else {
        let errorString: String = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return .fail(outputString + errorString + "❌ command \(command_log_string) failed.")
    }
}

func bash(command: String, arguments: [String]) -> Result {
    
    let commandPathResult: Result = script_processor(
        launchPath: "/bin/bash",
        arguments: ["-l", "-c", "which \(command)"]
    )
    switch commandPathResult {
    case .success(let info):
        return script_processor(launchPath: (info as! String).trimmingCharacters(in: .whitespacesAndNewlines), arguments: arguments)
    case .fail(_):
        return commandPathResult
    }
}

func build() -> Result {
    
    let projectPath: String = "AVOS/AVOS.xcodeproj"
    
    let check_installed_xcodebuild_result: Result = bash(
        command: "xcodebuild",
        arguments: ["-version"]
    )
    switch check_installed_xcodebuild_result {
    case .success(_): break
    case .fail(_): return check_installed_xcodebuild_result
    }
    
    var schemes: [String] = []
    var buildConfigurations: [String] = []
    let xcodebuild_list_result: Result = bash(
        command: "xcodebuild",
        arguments: [
            "-list",
            "-project", projectPath
        ]
    )
    switch xcodebuild_list_result {
    case .success(let info):
        let lines: [String] = (info as! String).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        schemes = {
            guard var startIndex: Int = lines.index(of: "Schemes:") else { return [] }
            guard let endIndex: Int = lines[startIndex...].index(of: "") else { return [] }
            startIndex += 1
            guard startIndex < endIndex else { return [] }
            let arraySlice: ArraySlice<String> = lines[startIndex..<endIndex].filter {
                $0.hasSuffix("-iOS") || $0.hasSuffix("-macOS") || $0.hasSuffix("-tvOS") || $0.hasSuffix("-watchOS")
            }
            return Array(arraySlice)
        }()
        buildConfigurations = {
            guard var startIndex: Int = lines.index(of: "Build Configurations:") else { return [] }
            guard let endIndex: Int = lines[startIndex...].index(of: "") else { return [] }
            startIndex += 1
            guard startIndex < endIndex else { return [] }
            let arraySlice: ArraySlice<String> = lines[startIndex..<endIndex]
            return Array(arraySlice)
        }()
        if schemes.isEmpty || buildConfigurations.isEmpty {
            return .fail("❌ not get schemes or build-configurations.")
        }
    case .fail(_):
        return xcodebuild_list_result
    }
    
    var build_result: Result! = nil
    for i in 0...schemes.count {
        let result: Result = {
            for scheme in schemes {
                for buildConfiguration in buildConfigurations {
                    let _result: Result = bash(
                        command: "xcodebuild",
                        arguments: [
                            "-project", projectPath,
                            "-scheme", scheme,
                            "-configuration", buildConfiguration,
                            "build",
                            "-quiet"
                        ]
                    )
                    switch _result {
                    case .success(let info):
                        print(info as! String)
                        print("✅ build \(scheme) \(buildConfiguration) success.")
                    case .fail(_): return _result
                    }
                }
            }
            return .success("\n" + "✅ all schemes build success.")
        }()
        switch result {
        case .success(_): build_result = result
        case .fail(_): if i == schemes.count { build_result = result }
        }
        if build_result != nil { break }
    }
    
    return build_result
}

func generate_podspec(version: String) -> Result {
    
    let check_installed_xcodeproj_result: Result = bash(
        command: "xcodeproj",
        arguments: ["--version"]
    )
    switch check_installed_xcodeproj_result {
    case .success(_): break
    case .fail(_): return check_installed_xcodeproj_result
    }
    
    let check_installed_mustache_result: Result = bash(
        command: "mustache",
        arguments: ["--version"]
    )
    switch check_installed_mustache_result {
    case .success(_): break
    case .fail(_): return check_installed_mustache_result
    }
    
    let userAgentContent: String = "#define SDK_VERSION @\"v\(version)\"\n"
    try! userAgentContent.write(toFile: "AVOS/AVOSCloud/UserAgent.h", atomically: true, encoding: .utf8)
    
    let result: Result = bash(command: "ruby", arguments: ["generate_podspec.rb", version])
    switch result {
    case .success(let info): return .success("\n" + "✅ " + (info as! String))
    case .fail(_): return result
    }
}

func git_commit_push(version: String) -> Result {
    
    let git_add_result: Result = bash(
        command: "git",
        arguments: ["add", "-A"]
    )
    switch git_add_result {
    case .success(let info): print(info as! String)
    case .fail(_): return git_add_result
    }
    
    let git_commit_result: Result = bash(
        command: "git",
        arguments: ["commit", "-a", "-m", "Release v\(version)"]
    )
    switch git_commit_result {
    case .success(let info): print(info as! String)
    case .fail(_): return git_commit_result
    }
    
    return bash(command: "git", arguments: ["push"])
}

func pod_trunk_push() {
    
    let check_installed_pod_result: Result = bash(
        command: "pod",
        arguments: ["--version"]
    )
    switch check_installed_pod_result {
    case .success(_): break
    case .fail(let error):
        print(error)
        return
    }
    
    for item in ["AVOSCloud.podspec", "AVOSCloudIM.podspec", "AVOSCloudLiveQuery.podspec"] {
        switch bash(command: "pod", arguments: ["trunk", "push", item, "--allow-warnings"]) {
        case .success(let info): print(info as! String)
        case .fail(let error): print(error)
        }
        switch bash(command: "pod", arguments: ["repo", "update"]) {
        case .success(let info): print(info as! String)
        case .fail(let error): print(error)
        }
    }
}

func doc_update() {
    
    let check_installed_appledoc_result: Result = bash(
        command: "appledoc",
        arguments: ["--version"]
    )
    switch check_installed_appledoc_result {
    case .success(_): break
    case .fail(let error):
        print(error)
        return
    }
    
    let tempHeadersFolder: String = "all_public_header_files_tmp/"
    let tempOutputFolder: String = "html/"
    guard !FileManager.default.fileExists(atPath: tempHeadersFolder), !FileManager.default.fileExists(atPath: tempOutputFolder) else {
        print("name conflicts when create folder '\(tempHeadersFolder)'")
        return
    }
    
    let apiDocFolder: String = "../api-docs/api/iOS"
    var isDirectory: ObjCBool = true
    guard FileManager.default.fileExists(atPath: apiDocFolder, isDirectory: &isDirectory), isDirectory.boolValue == true else {
        print("not found iOS doc folder path '\(apiDocFolder)', see https://github.com/leancloud/api-docs")
        return
    }
    
    do {
        let version: String = (try String(contentsOfFile: "AVOS/AVOSCloud/UserAgent.h", encoding: .utf8)).replacingOccurrences(of: "#define SDK_VERSION @\"v", with: "").replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let versionComponents: [String] = version.components(separatedBy: ".")
        for number in versionComponents {
            if Int(number) == nil || versionComponents.count != 3 {
                fatalError("version: \(version) invalid.")
            }
        }
        
        switch bash(command: "ruby", arguments: ["generate_podspec.rb", "public_header_files"]) {
        case .success(let info):
            try FileManager.default.createDirectory(atPath: tempHeadersFolder, withIntermediateDirectories: true, attributes: nil)
            let filePaths: [String] = (info as! String).components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            for item in filePaths {
                try FileManager.default.copyItem(atPath: item, toPath: "\(tempHeadersFolder)\(item.components(separatedBy: "/").last!)")
            }
        case .fail(let error):
            print(error)
            return
        }
        
        switch bash(command: "appledoc", arguments:[
            "--create-html",
            "--project-version", version,
            "--output", "./",
            "--company-id", "LeanCloud",
            "--project-company", "LeanCloud, Inc.",
            "--project-name", "LeanCloud Objective-C SDK",
            "--keep-undocumented-objects",
            "--keep-undocumented-members",
            "--no-install-docset",
            "--no-create-docset",
            tempHeadersFolder]
        ){
        case .success(let info):
            print(info as! String)
        case .fail(let error):
            print(error)
        }
        try FileManager.default.removeItem(atPath: apiDocFolder)
        try FileManager.default.removeItem(atPath: tempHeadersFolder)
        try FileManager.default.moveItem(atPath: tempOutputFolder, toPath: apiDocFolder)
    } catch {
        print(error)
    }
}

func main () {
    let arguments = CommandLine.arguments
    if arguments.count < 2 {
        print("❌ error arguments.")
        return
    } else {
        switch arguments[1] {
        case "build":
            switch build() {
            case .success(let info): print(info as! String)
            case .fail(let error): print(error)
            }
        case "podspec":
            let version: String = arguments[2]
            let versionComponents = version.components(separatedBy: ".")
            for number in versionComponents {
                if Int(number) == nil || versionComponents.count != 3 {
                    fatalError("version: \(version) invalid.")
                }
            }
            switch generate_podspec(version: version) {
            case .success(let info): print(info as! String)
            case .fail(let error): print(error)
            }
        case "release":
            pod_trunk_push()
        case "doc":
            doc_update()
        default:
            let version: String = arguments[1]
            let versionComponents: [String] = version.components(separatedBy: ".")
            for number in versionComponents {
                if Int(number) == nil || versionComponents.count != 3 {
                    fatalError("version: \(version) invalid.")
                }
            }
            switch build() {
            case .success(let info): print(info as! String)
            case .fail(let error):
                print(error)
                return
            }
            switch generate_podspec(version: version) {
            case .success(let info): print(info as! String)
            case .fail(let error):
                print(error)
                return
            }
            switch git_commit_push(version: version) {
            case .success(let info): print(info as! String)
            case .fail(let error):
                print(error)
                return
            }
        }
    }
}

main()
