import os

enum AppLogger {
    private static let subsystem = "com.razorbackroar.swifttemp"

    static let thermal = Logger(subsystem: subsystem, category: "thermal")
    static let system = Logger(subsystem: subsystem, category: "system")
}
