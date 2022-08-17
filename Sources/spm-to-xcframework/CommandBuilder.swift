import Foundation

struct CommandBuilder {
    private let path: String
    private let scheme: String
    private let enableLibraryEvolution: Bool
    private let outputPath: String
    let platforms: [Platform]

    init(
        scheme: String,
        path: String?,
        outputPath: String?,
        enableLibraryEvolution: Bool = false,
        platforms: [Platform] = []
    ) {
        self.scheme = scheme
        self.enableLibraryEvolution = enableLibraryEvolution
        self.platforms = platforms.isEmpty ? [.ios, .simulator, .watchos, .watchsimulator] : platforms

        if let value = path {
            self.path = (value as NSString).expandingTildeInPath
        } else {
            self.path = FileManager.default.currentDirectoryPath
        }

        if let value = outputPath {
            self.outputPath = (((value as NSString).expandingTildeInPath) as NSString).appendingPathComponent("Build")
        } else {
            self.outputPath = (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent("Build")
        }
    }
}

extension CommandBuilder {
    private var baseCommand: String {
        "xcodebuild -workspace \(path) -scheme \(scheme)"
    }

    private var buildDirCommand: String { "BUILD_DIR='\(outputPath)'" }
    private var frameworksPath: String { "\(outputPath)/frameworks" }
    private var xcframeworkPath: String { "\(outputPath)/xcframeworks" }
    private var resourcesPath: String { "\(outputPath)/resources" }

    var cleanCommand: String {
        "\(baseCommand) clean \(platforms.map(\.destination).joined(separator: " "))"
    }

    var buildCommands: [String: String] {
        let commands = platforms.reduce(into: [String: String]()) { commands, platform in
            commands[platform.sdk] =
                """
                \(baseCommand) \
                \(buildDirCommand) \
                \(platform.destination) \
                -configuration Release \
                -sdk \(platform.sdk) \
                BUILD_LIBRARY_FOR_DISTRIBUTION=\(enableLibraryEvolution ? "YES" : "NO") \
                ARCHS=\"\(platform.archs)\" \
                BITCODE_GENERATION_MODE=\(platform.supportsBitcode ? "bitcode" : "marker")
                """
        }

        return commands
    }

    var createFoldersCommands: [String] {
        let frameworkPaths = platforms.map {
            "mkdir -p \(outputPath)/Frameworks/\($0.name)"
        }

        return frameworkPaths + [
            "mkdir -p \(xcframeworkPath)",
            "mkdir -p \(resourcesPath)"
        ]
    }

    func frameworkNamesCommand(for platform: Platform) -> String {
        "find \(outputPath)/\(platform.buildFolder) -maxdepth 1 -name '*.o'"
    }

    func createFrameworkCommand(frameworkName name: String, platform: Platform) -> String {
        let libraryPath = "\(outputPath)/\(platform.buildFolder)/lib\(name).a"
        let objectPath = "\(outputPath)/\(platform.buildFolder)/\(name).o"
        let frameworkPath = "\(frameworksPath)/\(platform.name)/\(name).framework"
        let modulesPath = "\(frameworkPath)/Modules"

        let createLibrary = "ar -rcs \(libraryPath) \(objectPath)"

        let createModulesFolder = "mkdir -p \(modulesPath)"
        let copyLibrary = "cp \(libraryPath) \(frameworkPath)/\(name)"
        let copyModule = "cp -r \(outputPath)/\(platform.buildFolder)/\(name).swiftmodule \(modulesPath)"

        return [createLibrary, createModulesFolder, copyLibrary, copyModule]
            .joined(separator: "; ")
    }

    func xcframeworkCommand(for name: String) -> String {
        let allFrameworks = platforms
            .map { platform in
                "\(frameworksPath)/\(platform.name)/\(name).framework"
            }
            .joined(separator: " -framework ")

        return "xcodebuild -create-xcframework -framework \(allFrameworks) \(enableLibraryEvolution ? "" : "-allow-internal-distribution") -output \(xcframeworkPath)/\(name).xcframework"
    }

    func copyResourcesCommand(for frameworkName: String, platform: Platform) -> String {
        """
        if ls \(outputPath)/\(platform.buildFolder)/*_\(frameworkName).bundle 1> /dev/null 2>&1; then
            cp -r \(outputPath)/\(platform.buildFolder)/*_\(frameworkName).bundle \(resourcesPath)
        fi
        """
//        "cp -r \(outputPath)/\(platform.buildFolder)/\(frameworkName)_\(frameworkName).bundle \(frameworksPath)/\(platform.name)/\(frameworkName).framework"
    }

    var cleanupCommand: String {
        let commands = platforms.map { "rm -rf \(outputPath)/\($0.buildFolder)" } + ["rm -rf \(frameworksPath)"] + ["rm -rf \(outputPath)/Release"]
        return commands.joined(separator: "; ")
    }

    var openFolderCommand: String {
        "open \(outputPath)"
    }
}
