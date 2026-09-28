import Foundation
import Testing
@testable import CalcEngine

private let formatter = ValueFormatter(decimalSeparator: ",", groupingSeparator: " ")

private func result(_ text: String) -> String? {
    Calculator().evaluate(text).last?.value.map { formatter.format($0) }
}

@Suite("Miary i wagi")
struct UnitTests {
    @Test(arguments: [
        // Długość
        ("5 km in m", "5000 m"),
        ("5km", "5 km"),
        ("1 mila w km", "1,609344 km"),
        ("180 cm na ft", "5,905511811 ft"),
        ("1 cal w cm", "2,54 cm"),
        ("3 metry + 50 cm", "3,5 m"),
        ("3 km / 1500 m", "2"),
        // Waga
        ("2 kg + 50 dag", "2,5 kg"),
        ("1 lb in g", "453,59237 g"),
        ("30 deko w g", "300 g"),
        ("10 kg * 3", "30 kg"),
        ("2 tony w kg", "2000 kg"),
        // Objętość
        ("2 szklanki w ml", "500 ml"),
        ("3 łyżki in ml", "45 ml"),
        ("1 gal w l", "3,785411784 l"),
        ("1 m3 w litrach", "1000 l"),
        // Powierzchnia
        ("5 m * 4 m", "20 m²"),
        ("50 cm * 2 m", "10 000 cm²"),
        ("1 ha w m2", "10 000 m²"),
        ("60 m² in ar", "0,6 ar"),
        // Temperatura
        ("100 °F in °C", "37,7777777778 °C"),
        ("20 C in F", "68 °F"),
        ("0 K w C", "-273,15 °C"),
        ("21,5 °C", "21,5 °C"),
        // Dane
        ("1 GB in MB", "1000 MB"),
        ("1 GiB in MiB", "1024 MiB"),
        ("1,5 TB w GB", "1500 GB"),
        ("8 bitów w B", "1 B"),
        // Z resztą kalkulatora
        ("odl = 1 mila w km\nround(odl; 2)", "1,61 km"),
        ("10 km\n5 km\nsuma", "15 km"),
        ("dystans = 42,195 km\ndystans w mile", "26,2187574565 mi"),
    ])
    func converts(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test(arguments: ["5 kg + 3 m", "5 kg in l", "20 °C in kg", "5 km * 2 kg"])
    func incompatibleUnitsAreErrors(input: String) {
        #expect(result(input) == nil)
    }

    @Test func existingMeaningsStillWork() {
        #expect(result("255 in hex") == "0xFF")
        #expect(result("5 min") == "5 minut")
        #expect(result("min(3; 1)") == "1")
        #expect(result("m = 7\nm * 2") == "14")
        #expect(result("10 funtów") == "10,00 £")
    }
}
