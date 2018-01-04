#!/usr/bin/swift

import Foundation

enum Result {
    
    case success(Any?)
    
    case fail(String)
}

let timerQueue: DispatchQueue = DispatchQueue(label: "timerQueue")

var timeoutWorkItem: DispatchWorkItem?

var isTerminating: Bool = false

func script_processor(launchPath: String, arguments: [String], needOutput: Bool) -> Result {
    
    let task: Process = Process()
    
    task.launchPath = launchPath
    task.arguments = arguments
    
    let outputPipe: Pipe? = needOutput ? Pipe() : nil
    let errorPipe: Pipe = Pipe()
    
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    
    task.launch()
    
    timeoutWorkItem = DispatchWorkItem {
        
        isTerminating = true
        
        task.terminate()
    }
    
    let timeout: Int = 600
    
    timerQueue.asyncAfter(
        deadline: .now() + .seconds(timeout),
        execute: timeoutWorkItem!
    )
    
    task.waitUntilExit()
    
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    
    if isTerminating {
        
        isTerminating = false
        
        return .fail(
            """
            Timeout with Command: [\(arguments.joined(separator: " "))].
            
            In general, there are two cases.
            
            1. Task Process Deadlock
            
            2. The running time of the Task Process is more than Timeout(\(timeout) seconds)
            
            If it's the secondary case, you can change the Timeout.
            """
        )
        
    } else {
        
        if task.terminationStatus == 0 {
            
            let outputData: Data? = outputPipe?.fileHandleForReading.readDataToEndOfFile()
            
            let outputString: String? = outputData != nil
                ? String.init(data: outputData!, encoding: .utf8)
                : Optional<String>.init("Command [\(launchPath) \(arguments.joined(separator: " "))] Success.")
            
            return .success(outputString)
            
        } else {
            
            let errorData: Data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let errorString: String = String.init(data: errorData, encoding: .utf8)
                ?? "Unknown Error with Command: [\(arguments.joined(separator: " "))]."
            
            return .fail(errorString)
        }
    }
}

func bash(command: String, arguments: [String], needOutput: Bool) -> Result {
    
    let commandPathResult: Result = script_processor(
        launchPath: "/bin/bash",
        arguments: [ "-l", "-c", "which \(command)" ],
        needOutput: true
    )
    
    switch commandPathResult {
        
    case .success(let string):
        
        guard let path: String = (string as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            
            return .fail("Not found a path for '\(command)'.")
        }
        
        return script_processor(
            launchPath: path,
            arguments: arguments,
            needOutput: needOutput
        )
        
    case .fail(_):
        
        return commandPathResult
    }
}

func xcodebuild_list(projectPath: String) -> Result {
    
    let arguments: [String] = [
        "-list",
        "-project", projectPath
    ]
    
    let result: Result = bash(
        command: "xcodebuild",
        arguments: arguments,
        needOutput: true
    )
    
    switch result {
        
    case .success(let output):
        
        guard let _output: String = output as? String else {
            
            return .fail("Not get a valid output with Command: [\(arguments.joined(separator: " "))].")
        }
        
        let lines: [String] = _output.components(separatedBy: CharacterSet.newlines)
            
            .map { (item: String) -> (String) in
                
                return item.trimmingCharacters(in: CharacterSet.whitespaces) }
        
        return .success(lines)
        
    case .fail(_):
        
        return result
    }
}

func get_project_all_valid_schemes(lines: [String]) -> [String] {
    
    guard var startIndex: Int = lines.index(of: "Schemes:") else {
        
        return []
    }
    
    guard let endIndex: Int = lines[startIndex...].index(of: "") else {
        
        return []
    }
    
    startIndex += 1
    
    guard startIndex < endIndex else {
        
        return []
    }
    
    let arraySlice: ArraySlice<String> = lines[startIndex..<endIndex]
        
        .filter { (item: String) -> Bool in
            
            return !item.hasSuffix("Tests") }
    
    return Array(arraySlice)
}

func get_project_all_buildConfigurations(lines: [String]) -> [String] {
    
    guard var startIndex: Int = lines.index(of: "Build Configurations:") else {
        
        return []
    }
    
    guard let endIndex: Int = lines[startIndex...].index(of: "") else {
        
        return []
    }
    
    startIndex += 1
    
    guard startIndex < endIndex else {
        
        return []
    }
    
    let arraySlice: ArraySlice<String> = lines[startIndex..<endIndex]
    
    return Array(arraySlice)
}

func xcodebuild_building_schemes(projectPath: String, schemes: [String], buildConfigurations: [String]) -> Result {
    
    for scheme in schemes {
        
        for buildConfiguration in buildConfigurations {
            
            let arguments: [String] = [
                "-project", projectPath,
                "-scheme", scheme,
                "-configuration", buildConfiguration,
                "build"
            ]
            
            let result: Result = bash(
                command: "xcodebuild",
                arguments: arguments,
                needOutput: false
            )
            
            switch result {
                
            case .success(let output):
                
                if let _output: String = output as? String {
                    
                    print(_output)
                    
                } else {
                    
                    print("Command [\(arguments.joined(separator: " "))] Success.")
                }
            case .fail(_):
                
                return result
            }
        }
    }
    
    return .success("The Build of All Schemes are Success.")
}

func check_if_installed_xcodebuild() -> Result {
    
    let result: Result = bash(
        command: "xcodebuild",
        arguments: ["-version"],
        needOutput: true
    )
    
    return result
}

let projectPath: String = "AVOS/AVOS.xcodeproj"

func main() {
    
    let isInstalledXcodebuild: Result = check_if_installed_xcodebuild()
    
    guard case .success(_) = isInstalledXcodebuild else {
        
        if case let .fail(error) = isInstalledXcodebuild {
            
            print(error)
            
        } else {
            
            print("Not found 'xcodebuild'.")
        }
        
        return
    }
    
    let listResult: Result = xcodebuild_list(projectPath: projectPath)
    
    switch listResult {
        
    case .success(let stringArray):
        
        guard let lines: [String] = stringArray as? [String] else {
            
            fatalError()
        }
        
        let schemes: [String] = get_project_all_valid_schemes(lines: lines)
        
        let buildConfigurations: [String] = get_project_all_buildConfigurations(lines: lines)
        
        let buildResult: Result = xcodebuild_building_schemes(
            projectPath: projectPath,
            schemes: schemes,
            buildConfigurations: buildConfigurations
        )
        
        switch buildResult {
            
        case .success(let string):
            
            var output: String
            
            if let str: String = string as? String {
                
                output = str
                
            } else {
                
                output = String(describing: string)
            }
            
            
            print(
                """
                
                ✅✅✅
                
                \(output)
                
                """
            )
            
        case .fail(let error):
            
            print(
                """
                
                ❌❌❌
                
                \(error)
                
                """
            )
        }
        
    case .fail(let error):
        
        print(
            """
            
            ❌❌❌
            
            \(error)
            
            """
        )
    }
}

main()

