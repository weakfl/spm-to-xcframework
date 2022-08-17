import ArgumentParser

struct Platform {
    let name: String
    let destination: String
    let sdk: String
    let archs: String
    let supportsBitcode: Bool
    let buildFolder: String
}

extension Platform {
    static let ios = Platform(
        name: "ios",
        destination: "-destination generic/platform=iOS",
        sdk: "iphoneos",
        archs: "arm64",
        supportsBitcode: Platform.isBitcodeSupported,
        buildFolder: "Release-iphoneos"
    )
}

extension Platform {
    static let simulator = Platform(
        name: "simulator",
        destination: "-destination 'generic/platform=iOS Simulator'",
        sdk: "iphonesimulator",
        archs: "x86_64 arm64",
        supportsBitcode: false,
        buildFolder: "Release-iphonesimulator"
    )
}

extension Platform {
    static let watchos = Platform(
        name: "watchos",
        destination: "-destination 'generic/platform=watchOS'",
        sdk: "watchos",
        archs: "arm64_32",
        supportsBitcode: Platform.isBitcodeSupported,
        buildFolder: "Release-watchos"
    )
}

extension Platform {
    static let watchsimulator = Platform(
        name: "watchsimulator",
        destination: "-destination 'generic/platform=watchOS Simulator'",
        sdk: "watchsimulator",
        archs: "x86_64 arm64",
        supportsBitcode: false,
        buildFolder: "Release-watchsimulator"
    )
}

extension Platform: ExpressibleByArgument {
    init?(argument: String) {
        switch argument {
        case "ios": self = .ios
        case "simulator": self = .simulator
        case "watchos": self = .watchos
        case "watchsimulator": self = .watchsimulator
        default: return nil
        }
    }
}

private extension Platform {
    #if swift(>=5.7)
    static let isBitcodeSupported = false
    #else
    static let isBitcodeSupported = true
    #endif
}

extension Array: ExpressibleByArgument where Element: ExpressibleByArgument {
    public init?(argument: String) {
        self = argument.split(separator: " ")
            .compactMap { Element.init(argument: String($0)) }
    }
}
