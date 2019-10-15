#!/usr/bin/swift

import Foundation

struct TaskError: Error, CustomStringConvertible {
    var description: String {
        return self._description
    }
    let _description: String
    init(description: String = "",
         _ file: String = #file,
         _ function: String = #function,
         _ line: Int = #line)
    {
        self._description = """
        ------ Error ------
        file: \(file)
        function: \(function)
        line: \(line)
        description: \(description)
        ------ End --------
        """
    }
}

class Task {
    let task: Process = Process()
    
    init(launchPath: String, arguments: [String] = []) {
        self.task.launchPath = launchPath
        if !arguments.isEmpty {
            self.task.arguments = arguments
        }
        self.task.standardOutput = Pipe()
        self.task.standardError = Pipe()
    }
    
    func excute(
        printOutput: Bool = true,
        _ completion: ((Process) -> Void)? = nil)
        -> Bool
    {
        var success: Bool = false
        let group = DispatchGroup()
        group.enter()
        do {
            self.task.terminationHandler = {
                success = ($0.terminationStatus == 0)
                if let error = String(
                    data: ($0.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8) {
                    print(error)
                }
                if printOutput, let output = String(
                    data: ($0.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8) {
                    print(output)
                }
                completion?($0)
                group.leave()
            }
            try self.task.run()
            self.task.waitUntilExit()
        } catch {
            print(error)
            group.leave()
        }
        group.wait()
        return success
    }
}

class XcodebuildTask: Task {
    static let projectPath = "./AVOS/AVOS.xcodeproj"
    
    struct Xcodeproj: Decodable {
        let project: Project
        
        struct Project: Decodable {
            let configurations: [String]
            let name: String
            let schemes: [String]
            let targets: [String]
        }
    }
    
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/xcrun",
            arguments: ["xcodebuild"] + arguments)
    }
    
    static func version() throws {
        if !XcodebuildTask(arguments: ["-version"])
            .excute(printOutput: false) {
            throw TaskError()
        }
    }
    
    static func getXcodeproj(name: String) throws -> Xcodeproj {
        try version()
        var project: Xcodeproj!
        var taskError: Error?
        _ = XcodebuildTask(arguments: ["-list", "-project", name, "-json"])
            .excute(printOutput: false, {
                do {
                    let data = ($0.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile()
                    project = try JSONDecoder().decode(Xcodeproj.self, from: data)
                } catch {
                    taskError = error
                }
            })
        if let error = taskError {
            throw error
        } else {
            return project
        }
    }
    
    static func building(
        project: String,
        scheme: String,
        configuration: String,
        destination: String? = nil)
        throws
    {
        try version()
        var arguments: [String] = [
            "-project", project,
            "-scheme", scheme,
            "-configuration", configuration]
        if let destination = destination {
            arguments += ["-destination", destination]
        }
        arguments += ["clean", "build", "-quiet"]
        let success = XcodebuildTask(arguments: arguments).excute {
            let argumentsString = String(
                data: try! JSONSerialization.data(
                    withJSONObject: ($0.arguments ?? []),
                    options: [.prettyPrinted]),
                encoding: .utf8)
            print("""
                ------ Build Task ------
                Completion Status: \($0.terminationStatus == 0 ? "Complete Success 🎉" : "\($0.terminationStatus)")
                Launch Path: \($0.launchPath ?? "")
                Arguments: \(argumentsString ?? "")
                ------ End -------------
                """)
        }
        if !success {
            throw TaskError()
        }
    }
    
    enum SchemeSuffix: String {
        case iOS
        case macOS
        case tvOS
        case watchOS
    }
    
    static func building(
        project: String = XcodebuildTask.projectPath,
        schemeSuffixes: [SchemeSuffix] = [.iOS, .macOS, .tvOS, .watchOS])
        throws
    {
        let xcodeproj = try getXcodeproj(name: project)
        try xcodeproj.project.schemes.forEach { (scheme) in
            try schemeSuffixes.forEach { (schemeSuffix) in
                guard scheme.hasSuffix(schemeSuffix.rawValue) else {
                    return
                }
                try xcodeproj.project.configurations.forEach { (configuration) in
                    try building(
                        project: project,
                        scheme: scheme,
                        configuration: configuration,
                        destination: scheme.hasSuffix(SchemeSuffix.macOS.rawValue) ?
                            nil : "generic/platform=\(schemeSuffix.rawValue)")
                }
            }
        }
    }
}

class GitTask: Task {
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["git"] + arguments)
    }
}

class PodTask: Task {
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["pod"] + arguments)
    }
    
    static func trunkPush(path: String) throws {
        if !PodTask(arguments: ["trunk", "push", path, "--allow-warnings"]).excute() {
            print("RE: pod trunk push \(path) ? Y/n")
            if let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                line.lowercased() == "y" {
                try PodTask.trunkPush(path: path)
            } else {
                throw TaskError()
            }
        }
    }
    
    static func trunkPush(paths: [String]) throws {
        try paths.forEach { (path) in
            try PodTask.trunkPush(path: path)
        }
    }
}

class VersionUpdater {
    static let userAgentFilePath: String = "./AVOS/AVOSCloud/UserAgent.h"
    static let AVOSCloudPodspecFilePath: String = "./AVOSCloud.podspec"
    static let AVOSCloudIMPodspecFilePath: String = "./AVOSCloudIM.podspec"
    static let AVOSCloudLiveQueryPodspecFilePath: String = "./AVOSCloudLiveQuery.podspec"
    
    static func checkFileExists(path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            throw TaskError(description: "\(path) not found.")
        }
    }
    
    enum IncrementalPart {
        case major
        case minor
        case revision
        case tag
    }
    
    struct Version {
        let major: Int
        let minor: Int
        let revision: Int
        let tag: (category: String, number: Int)?
        
        var versionString: String {
            var string = "\(major).\(minor).\(revision)"
            if let tag = tag {
                string = "\(string)-\(tag.category).\(tag.number)"
            }
            return string
        }
        
        init(major: Int, minor: Int, revision: Int, tag: (String, Int)? = nil) {
            self.major = major
            self.minor = minor
            self.revision = revision
            self.tag = tag
        }
        
        init(string: String) throws {
            var versionString: String = string
            var tag: (String, Int)?
            if versionString.contains("-") {
                let components = versionString.components(separatedBy: "-")
                guard components.count == 2 else {
                    throw TaskError(description: "invalid semantic version: \(string).")
                }
                versionString = components[0]
                let tagComponents = components[1].components(separatedBy: ".")
                guard tagComponents.count == 2,
                    let tagNumber = Int(tagComponents[1]) else {
                        throw TaskError(description: "invalid semantic version: \(string).")
                }
                tag = (tagComponents[0], tagNumber)
            }
            let numbers = versionString.components(separatedBy: ".")
            guard numbers.count == 3,
                let major = Int(numbers[0]),
                let minor = Int(numbers[1]),
                let revision = Int(numbers[2]) else {
                    throw TaskError(description: "invalid semantic version: \(string).")
            }
            self.major = major
            self.minor = minor
            self.revision = revision
            self.tag = tag
        }
        
        func newVersion(increase part: IncrementalPart) throws -> Version {
            guard [.major, .minor, .revision].contains(part) && self.tag == nil else {
                throw TaskError(description: "tag exist.")
            }
            switch part {
            case .major:
                return Version(major: self.major + 1, minor: self.minor, revision: self.revision)
            case .minor:
                return Version(major: self.major, minor: self.minor + 1, revision: self.revision)
            case .revision:
                return Version(major: self.major, minor: self.minor, revision: self.revision + 1)
            case .tag:
                guard let tag = self.tag else {
                    throw TaskError(description: "tag not found.")
                }
                return Version(
                    major: self.major,
                    minor: self.minor,
                    revision: self.revision,
                    tag: (tag.category, tag.number + 1))
            }
        }
    }
    
    static func currentVersion(path: String = VersionUpdater.userAgentFilePath) throws -> Version {
        try checkFileExists(path: path)
        return try Version(string: String((try String(contentsOfFile: path, encoding: .utf8))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropFirst(#"#define SDK_VERSION @""#.count)
            .dropLast()))
    }
}

class CLI {
    
    static func help() {
        
    }
    
    static func build() throws {
        try XcodebuildTask.building()
    }
    
    static func githubRelease() {
        
    }
    
    static func podTrunk() {
        
    }
    
    static func read() -> [String] {
        var args = CommandLine.arguments
        args.removeFirst()
        return args
    }
    
    static func process(action: String) {
        switch action {
        case "b", "build":
            do {
                try build()
            } catch {
                print(error)
            }
        default:
            print("[!] Unknown Action: `\(action)`")
        }
    }
    
    static func run() {
        let args = read()
        switch args.count {
        case 1:
            process(action: args[0])
        default:
            print("[!] Unknown Command: `\(args.joined(separator: " "))`")
        }
    }
}

func main() {
    CLI.run()
}

main()

//enum Result {
//    case success(Any?)
//    case fail(String)
//}
//
//let timerQueue: DispatchQueue = DispatchQueue(label: "timerQueue")
//var timeoutWorkItem: DispatchWorkItem?
//var isTerminating: Bool = false
//
//func script_processor(launchPath: String, arguments: [String]) -> Result {
//
//    let task: Process = Process()
//    let outputPipe: Pipe = Pipe()
//    let errorPipe: Pipe = Pipe()
//    task.launchPath = launchPath
//    task.arguments = arguments
//    task.standardOutput = outputPipe
//    task.standardError = errorPipe
//    task.launch()
//    timeoutWorkItem = DispatchWorkItem {
//        isTerminating = true
//        task.terminate()
//    }
//    timerQueue.asyncAfter(
//        deadline: .now() + .seconds(600),
//        execute: timeoutWorkItem!
//    )
//    task.waitUntilExit()
//    timeoutWorkItem?.cancel()
//    timeoutWorkItem = nil
//
//    let command_log_string: String = "[\(launchPath) \(arguments.joined(separator: " "))]"
//
//    if isTerminating {
//        isTerminating = false
//        return .fail("❌ command \(command_log_string) timeout.")
//    }
//
//    let outputString: String = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
//    if task.terminationStatus == 0 {
//        return .success(outputString)
//    } else {
//        let errorString: String = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
//        return .fail(outputString + errorString + "❌ command \(command_log_string) failed.")
//    }
//}
//
//func bash(command: String, arguments: [String]) -> Result {
//
//    let commandPathResult: Result = script_processor(
//        launchPath: "/bin/bash",
//        arguments: ["-l", "-c", "which \(command)"]
//    )
//    switch commandPathResult {
//    case .success(let info):
//        return script_processor(launchPath: (info as! String).trimmingCharacters(in: .whitespacesAndNewlines), arguments: arguments)
//    case .fail(_):
//        return commandPathResult
//    }
//}
//
//func build() -> Result {
//
//    let projectPath: String = "AVOS/AVOS.xcodeproj"
//
//    let check_installed_xcodebuild_result: Result = bash(
//        command: "xcodebuild",
//        arguments: ["-version"]
//    )
//    switch check_installed_xcodebuild_result {
//    case .success(_): break
//    case .fail(_): return check_installed_xcodebuild_result
//    }
//
//    var schemes: [String] = []
//    var buildConfigurations: [String] = []
//    let xcodebuild_list_result: Result = bash(
//        command: "xcodebuild",
//        arguments: [
//            "-list",
//            "-project", projectPath
//        ]
//    )
//    switch xcodebuild_list_result {
//    case .success(let info):
//        let lines: [String] = (info as! String).components(separatedBy: .newlines)
//            .map { $0.trimmingCharacters(in: .whitespaces) }
//        schemes = {
//            guard var startIndex: Int = lines.firstIndex(of: "Schemes:") else { return [] }
//            guard let endIndex: Int = lines[startIndex...].firstIndex(of: "") else { return [] }
//            startIndex += 1
//            guard startIndex < endIndex else { return [] }
//            let arraySlice: ArraySlice<String> = lines[startIndex..<endIndex].filter {
//                $0.hasSuffix("-iOS") || $0.hasSuffix("-macOS") || $0.hasSuffix("-tvOS") || $0.hasSuffix("-watchOS")
//            }
//            return Array(arraySlice)
//        }()
//        buildConfigurations = {
//            guard var startIndex: Int = lines.firstIndex(of: "Build Configurations:") else { return [] }
//            guard let endIndex: Int = lines[startIndex...].firstIndex(of: "") else { return [] }
//            startIndex += 1
//            guard startIndex < endIndex else { return [] }
//            let arraySlice: ArraySlice<String> = lines[startIndex..<endIndex]
//            return Array(arraySlice)
//        }()
//        if schemes.isEmpty || buildConfigurations.isEmpty {
//            return .fail("❌ not get schemes or build-configurations.")
//        }
//    case .fail(_):
//        return xcodebuild_list_result
//    }
//
//    var build_result: Result! = nil
//    for i in 0...schemes.count {
//        let result: Result = {
//            for scheme in schemes {
//                for buildConfiguration in buildConfigurations {
//                    let _result: Result = bash(
//                        command: "xcodebuild",
//                        arguments: [
//                            "-project", projectPath,
//                            "-scheme", scheme,
//                            "-configuration", buildConfiguration,
//                            "build",
//                            "-quiet"
//                        ]
//                    )
//                    switch _result {
//                    case .success(let info):
//                        print(info as! String)
//                        print("✅ build \(scheme) \(buildConfiguration) success.")
//                    case .fail(_): return _result
//                    }
//                }
//            }
//            return .success("\n" + "✅ all schemes build success.")
//        }()
//        switch result {
//        case .success(_): build_result = result
//        case .fail(_): if i == schemes.count { build_result = result }
//        }
//        if build_result != nil { break }
//    }
//
//    return build_result
//}
//
//func validate_version(version: String) -> Result {
//
//    let versionComponents: [String] = version.components(separatedBy: ".")
//    guard versionComponents.count == 3 else {
//        return .fail("invalid version: \(version)")
//    }
//    for number in versionComponents {
//        if Int(number) == nil {
//            return .fail("invalid version: \(version)")
//        }
//    }
//    return .success(version)
//}
//
//func current_version() -> Result {
//    do {
//        let filePath: String = "AVOS/AVOSCloud/UserAgent.h"
//        let version: String = (try String(contentsOfFile: filePath, encoding: .utf8)).replacingOccurrences(of: "#define SDK_VERSION @\"v", with: "").replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
//        switch validate_version(version: version) {
//        case .success(_): return .success(version)
//        case .fail(_): return .fail("invalid version: \(version) in \(filePath)")
//        }
//    } catch {
//        return .fail("\(error)")
//    }
//}
//
//func generate_podspec(version: String) -> Result {
//
//    let check_installed_xcodeproj_result: Result = bash(
//        command: "xcodeproj",
//        arguments: ["--version"]
//    )
//    switch check_installed_xcodeproj_result {
//    case .success(_): break
//    case .fail(_): return check_installed_xcodeproj_result
//    }
//
//    let check_installed_mustache_result: Result = bash(
//        command: "mustache",
//        arguments: ["--version"]
//    )
//    switch check_installed_mustache_result {
//    case .success(_): break
//    case .fail(_): return check_installed_mustache_result
//    }
//
//    let userAgentContent: String = "#define SDK_VERSION @\"v\(version)\"\n"
//    try! userAgentContent.write(toFile: "AVOS/AVOSCloud/UserAgent.h", atomically: true, encoding: .utf8)
//
//    let result: Result = bash(command: "ruby", arguments: ["generate_podspec.rb", version])
//    switch result {
//    case .success(let info): return .success("\n" + "✅ " + (info as! String))
//    case .fail(_): return result
//    }
//}
//
//func git_commit_push(version: String) -> Result {
//
//    let git_add_result: Result = bash(
//        command: "git",
//        arguments: ["add", "-A"]
//    )
//    switch git_add_result {
//    case .success(let info): print(info as! String)
//    case .fail(_): return git_add_result
//    }
//
//    let git_commit_result: Result = bash(
//        command: "git",
//        arguments: ["commit", "-a", "-m", "Release v\(version)"]
//    )
//    switch git_commit_result {
//    case .success(let info): print(info as! String)
//    case .fail(_): return git_commit_result
//    }
//
//    return bash(command: "git", arguments: ["push"])
//}
//
//func pod_trunk_push() {
//
//    let check_installed_pod_result: Result = bash(
//        command: "pod",
//        arguments: ["--version"]
//    )
//    switch check_installed_pod_result {
//    case .success(_): break
//    case .fail(let error):
//        print(error)
//        return
//    }
//
//    for item in ["AVOSCloud.podspec", "AVOSCloudIM.podspec", "AVOSCloudLiveQuery.podspec"] {
//        switch bash(command: "pod", arguments: ["trunk", "push", item, "--allow-warnings"]) {
//        case .success(let info): print(info as! String)
//        case .fail(let error):
//            print(error)
//            return
//        }
//        switch bash(command: "pod", arguments: ["repo", "update"]) {
//        case .success(let info): print(info as! String)
//        case .fail(let error):
//            print(error)
//            return
//        }
//    }
//}
//
//func doc_update() {
//
//    let check_installed_appledoc_result: Result = bash(
//        command: "appledoc",
//        arguments: ["--version"]
//    )
//    switch check_installed_appledoc_result {
//    case .success(_): break
//    case .fail(let error):
//        print(error)
//        return
//    }
//
//    let tempHeadersFolder: String = "all_public_header_files_tmp/"
//    let tempOutputFolder: String = "html/"
//    guard !FileManager.default.fileExists(atPath: tempHeadersFolder),
//        !FileManager.default.fileExists(atPath: tempOutputFolder) else
//    {
//        print("name conflicts when create folder '\(tempHeadersFolder)'")
//        return
//    }
//
//    let apiDocFolder: String = "../api-docs/api/iOS"
//    var apiDocFolderIsDirectory: ObjCBool = true
//    guard FileManager.default.fileExists(atPath: apiDocFolder, isDirectory: &apiDocFolderIsDirectory),
//        apiDocFolderIsDirectory.boolValue == true else
//    {
//        print("not found iOS doc folder path '\(apiDocFolder)', see https://github.com/leancloud/api-docs")
//        return
//    }
//
//    switch current_version() {
//    case .success(let info):
//        let version: String = info as! String
//        do {
//            switch bash(command: "ruby", arguments: ["generate_podspec.rb", "public_header_files"]) {
//            case .success(let info):
//                try FileManager.default.createDirectory(atPath: tempHeadersFolder, withIntermediateDirectories: true, attributes: nil)
//                let filePaths: [String] = (info as! String).components(separatedBy: .newlines)
//                    .map { $0.trimmingCharacters(in: .whitespaces) }
//                    .filter { !$0.isEmpty }
//                for item in filePaths {
//                    try FileManager.default.copyItem(atPath: item, toPath: "\(tempHeadersFolder)\(item.components(separatedBy: "/").last!)")
//                }
//            case .fail(let error):
//                print(error)
//                return
//            }
//
//            let appledocResult: Result = bash(command: "appledoc", arguments:[
//                "--create-html",
//                "--project-version", version,
//                "--output", "./",
//                "--company-id", "LeanCloud",
//                "--project-company", "LeanCloud, Inc.",
//                "--project-name", "LeanCloud Objective-C SDK",
//                "--keep-undocumented-objects",
//                "--keep-undocumented-members",
//                "--no-install-docset",
//                "--no-create-docset",
//                tempHeadersFolder]
//            )
//            try FileManager.default.removeItem(atPath: tempHeadersFolder)
//            var tempOutputFolderIsDirectory: ObjCBool = true
//            if FileManager.default.fileExists(atPath: tempOutputFolder, isDirectory: &tempOutputFolderIsDirectory),
//                tempOutputFolderIsDirectory.boolValue == true
//            {
//                try FileManager.default.removeItem(atPath: apiDocFolder)
//                try FileManager.default.moveItem(atPath: tempOutputFolder, toPath: apiDocFolder)
//            } else {
//                print("not found \(tempOutputFolder) folder")
//            }
//            switch appledocResult {
//            case .success(let info):
//                print(info as! String)
//            case .fail(let error):
//                print(error)
//            }
//        } catch {
//            print(error)
//        }
//    case .fail(let error): print(error)
//    }
//}
//
//let help: String =
//"""
//
//-v, --version
//    Current version of all frameworks in CocoaPods.
//
//-b, --build
//    Build all framework targets with configurations.
//
//-p, --podspec_generate <version>
//    Generate all podspec with specific version.
//
//-r, --release
//    Pod trunk push.
//
//-d, --doc_update
//    Update API document.
//
//-h, --help
//    Usage help.
//
//"""
//
//func main () {
//    let arguments = CommandLine.arguments
//    guard arguments.count >= 2 else {
//        print("❌ error arguments.\n\(help)")
//        return
//    }
//    switch arguments[1] {
//    case "-v", "--version":
//        switch current_version() {
//        case .success(let info):
//            let currentVersion: String = info as! String
//            print("\ncurrent version is \(currentVersion)")
//            print("\ndo you want to commit with new version? [<new_version>/n(N)] \n")
//            let newVersion = readLine()!
//            if newVersion == "n" || newVersion == "N" {
//                return
//            }
//            switch validate_version(version: newVersion) {
//            case .success(_):
//                switch build() {
//                case .success(let info): print(info as! String)
//                case .fail(let error):
//                    print(error)
//                    return
//                }
//                switch generate_podspec(version: newVersion) {
//                case .success(let info): print(info as! String)
//                case .fail(let error):
//                    print(error)
//                    return
//                }
//                switch git_commit_push(version: newVersion) {
//                case .success(let info): print(info as! String)
//                case .fail(let error):
//                    print(error)
//                    return
//                }
//            case .fail(let error):
//                print(error)
//                return
//            }
//        case .fail(let error):
//            print(error)
//            return
//        }
//    case "-b", "--build":
//        switch build() {
//        case .success(let info): print(info as! String)
//        case .fail(let error):
//            print(error)
//            return
//        }
//    case "-p", "--podspec_generate":
//        guard arguments.count >= 3 else {
//            print("❌ need a version")
//            return
//        }
//        let version: String = arguments[2]
//        switch validate_version(version: version) {
//        case .success(_):
//            switch generate_podspec(version: version) {
//            case .success(let info): print(info as! String)
//            case .fail(let error):
//                print(error)
//                return
//            }
//        case .fail(let error):
//            print(error)
//            return
//        }
//    case "-r", "--release": pod_trunk_push()
//    case "-d", "--doc_update": doc_update()
//    case "-h", "--help": print(help)
//    default:
//        print("❌ error arguments.\n\(help)")
//        return
//    }
//}
//
//main()
