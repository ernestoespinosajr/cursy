import Testing

@main
struct SessionTestRunner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
