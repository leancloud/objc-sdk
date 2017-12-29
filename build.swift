#!/usr/bin/swift

import Foundation

enum Result {
    
    case success(Any?)
    
    case fail(String)
}

let timerQueue: DispatchQueue = DispatchQueue(label: "timerQueue")

var timeoutWorkItem: DispatchWorkItem?

var isTerminating: Bool = false

func scriptProcessor(launchPath: String, arguments: [String]) -> Result {
    
    let task: Process = Process()
    
    task.launchPath = launchPath
    task.arguments = arguments
    
    let outputPipe: Pipe = Pipe()
    let errorPipe: Pipe = Pipe()
    
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    
    task.launch()
    
    timeoutWorkItem = DispatchWorkItem {
        
        isTerminating = true
        
        task.terminate()
    }
    
    timerQueue.asyncAfter(
        deadline: .now() + .seconds(60),
        execute: timeoutWorkItem!
    )
    
    task.waitUntilExit()
    
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    
    let outputData: Data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData: Data = errorPipe.fileHandleForReading.readDataToEndOfFile()
    
    let outputString: String? = String.init(data: outputData, encoding: .utf8)
    let errorString: String? = String.init(data: errorData, encoding: .utf8)
    
    if isTerminating {
        
        isTerminating = false
        
        return .fail("Timeout with Command: \(arguments)")
        
    } else {
        
        if task.terminationStatus == 0 {
            
            return .success(outputString)
            
        } else {
            
            return .fail(errorString ?? "Unknown Error with Command: \(arguments)")
        }
    }
}

func commandLineInterface(arguments: [String]) -> Result {
    
    return scriptProcessor(launchPath: "/usr/bin/env", arguments: arguments)
}

func xcodebuild_List(projectPath: String) -> Result {
    
    let result: Result = commandLineInterface(arguments: ["xcodebuild", "-list", "-project", projectPath])
    
    switch result {
        
    case .success(let output):
        
        guard let _output: String = output as? String else {
            
            return .fail("\(#function) unwrapped output is invalid.")
        }
        
        let lines: [String] = _output.components(separatedBy: CharacterSet.newlines)
            
            .map { (item: String) -> (String) in
                
                return item.trimmingCharacters(in: CharacterSet.whitespaces) }
        
        return .success(lines)
        
    case .fail(_):
        
        return result
    }
}

func getProjectAllValidTargets(lines: [String]) -> [String] {
    
    guard var startIndex: Int = lines.index(of: "Targets:") else {
        
        return []
    }
    
    guard let endIndex: Int = lines[startIndex...].index(of: "") else {
        
        return []
    }
    
    startIndex += 1
    
    guard startIndex < endIndex else {
        
        return []
    }
    
    let allTargetArray: ArraySlice<String> = lines[startIndex..<endIndex]
    
    let allValidTargetArray: [String] = Array(allTargetArray)
        
        .filter { (item: String) -> Bool in
            
            return !item.hasSuffix("Tests") }
    
    return allValidTargetArray
}

func getProjectAllBuildConfigurations(lines: [String]) -> [String] {
    
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
    
    let allBuildConfigurations: ArraySlice<String> = lines[startIndex..<endIndex]
    
    return Array(allBuildConfigurations)
}

func xcodebuild_BuildTargets(projectPath: String, targets: [String], buildConfigurations: [String]) -> Result {
    
    for target in targets {
        
        for buildConfiguration in buildConfigurations {
            
            let arguments: [String] = [
                "xcodebuild",
                "-project", projectPath,
                "-target", target,
                "-configuration", buildConfiguration
            ]
            
            let result: Result = commandLineInterface(arguments: arguments)
            
            switch result {
                
            case .success(let output):
                
                if let _output: String = output as? String {
                    
                    print(_output)
                    
                } else {
                    
                    print("Command \(arguments) Success.")
                }
            case .fail(_):
                
                return result
            }
        }
    }
    
    return .success("The Build of All Targets are Success.")
}

let projectPath: String = "AVOS/AVOS.xcodeproj"

func main() {
    
    let listResult: Result = xcodebuild_List(projectPath: projectPath)
    
    switch listResult {
        
    case .success(let lines):
        
        guard let _lines: [String] = lines as? [String] else {
            
            let comment: String =
            """
            
            ❌❌❌
            
            Get a invalid `Lines`:
            
            \(String(describing: lines))
            
            """
            
            print(comment)
            
            return
        }
        
        let targets: [String] = getProjectAllValidTargets(lines: _lines)
        
        let buildConfigurations: [String] = getProjectAllBuildConfigurations(lines: _lines)
        
        let buildResult: Result = xcodebuild_BuildTargets(
            projectPath: projectPath,
            targets: targets,
            buildConfigurations: buildConfigurations
        )
        
        switch buildResult {
            
        case .success(let output):
            
            var _output: String
            
            if let str: String = output as? String {
                
                _output = str
                
            } else {
                
                _output = String(describing: output)
            }
            
            let comment: String =
            """
            
            ✅✅✅
            
            \(_output)
            
            """
            
            print(comment)
            
        case .fail(let error):
            
            let comment: String =
            """
            
            ❌❌❌
            
            \(error)
            
            """
            
            print(comment)
        }
        
    case .fail(let error):
        
        let comment: String =
        """
        
        ❌❌❌
        
        \(error)
        
        """
        
        print(comment)
    }
}

main()
