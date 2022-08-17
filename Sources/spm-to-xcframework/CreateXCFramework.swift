import ArgumentParser
import Foundation

@main
struct CreateXCFramework: ParsableCommand {
    @Argument var packageName: String
    @Option var output: String?
    @Option var path: String?
    @Flag var enableLibraryEvolution: Bool = false
    @Flag var showOutput: Bool = false
    @Option var platforms: [Platform]?

    func run() throws {
        let commandBuilder = CommandBuilder(
            scheme: packageName,
            path: path,
            outputPath: output,
            enableLibraryEvolution: enableLibraryEvolution,
            platforms: platforms ?? []
        )

        createxcframeworks(with: commandBuilder)
    }

    func createxcframeworks(with commandBuilder: CommandBuilder) {
        do {
            print("Cleaning package '\(packageName)'")
            try execute(commandBuilder.cleanCommand)

            print("Start building package '\(packageName)'")
            try commandBuilder.buildCommands.forEach { sdk, command in
                print("Building '\(packageName)' for \(sdk)")
                try execute(command)
            }
            try commandBuilder.createFoldersCommands.forEach {
                try execute($0)
            }

            let platform = commandBuilder.platforms.first ?? .ios
            let frameworkNames = try frameworkNames(from: commandBuilder.frameworkNamesCommand(for: platform))

            try commandBuilder.platforms.forEach { platform in
                try frameworkNames.forEach { name in
                    let command = commandBuilder.createFrameworkCommand(frameworkName: name, platform: platform)
                    try execute(command)
                }
            }

            print("Creating XCFrameworks")
            try frameworkNames.forEach { name in
                try execute(commandBuilder.copyResourcesCommand(for: name, platform: platform))
                try execute(commandBuilder.xcframeworkCommand(for: name))
            }

            try execute(commandBuilder.cleanupCommand)
            print("Finished building package '\(packageName)'")

            if showOutput {
                try execute(commandBuilder.openFolderCommand)
            }
        } catch {
            print("Build failed with: \(error.localizedDescription)")
        }
    }

    func frameworkNames(from command: String) throws -> [String] {
        try execute(command)
                .split(separator: "\n")
                .compactMap { $0.split(separator: "/").last?.dropLast(2) }
                .map { String($0) }
    }

    @discardableResult
    func execute(_ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        try task.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw "Error \(task.terminationStatus)\n\n\(output)"
        }

        return output
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
