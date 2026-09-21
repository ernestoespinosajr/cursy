import Testing
@testable import Cursy

@Suite("Home glass accessibility and availability")
struct HomeGlassMaterialTests {
    @Test(arguments: [false, true], [false, true])
    func accessibilityTakesPriority(supportsGlass: Bool, increasedContrast: Bool) {
        #expect(HomeGlassMaterial.resolve(reduceTransparency: true,
            increasedContrast: increasedContrast, supportsLiquidGlass: supportsGlass) == .opaque)
    }

    @Test(arguments: [false, true])
    func increasedContrastUsesSolidSurface(supportsGlass: Bool) {
        #expect(HomeGlassMaterial.resolve(reduceTransparency: false,
            increasedContrast: true, supportsLiquidGlass: supportsGlass) == .opaque)
    }

    @Test func glassIsAvailabilityGated() {
        #expect(HomeGlassMaterial.resolve(reduceTransparency: false,
            increasedContrast: false, supportsLiquidGlass: true) == .liquidGlass)
        #expect(HomeGlassMaterial.resolve(reduceTransparency: false,
            increasedContrast: false, supportsLiquidGlass: false) == .visualEffect)
    }
}
