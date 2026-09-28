import Foundation

/// Jednostki miar i wag: długość, waga, objętość, powierzchnia, temperatura, dane.
public struct PhysicalUnit: Sendable, Hashable {
    public enum Dimension: Sendable, Hashable {
        case length, mass, volume, area, temperature, data
    }

    /// Symbol pokazywany w wyniku: `km`, `kg`, `m²`, `°C`.
    public let symbol: String
    public let dimension: Dimension
    /// Ile jednostek bazowych (m, kg, l, m², B) mieści jedna ta jednostka.
    let factor: Decimal

    static func named(_ word: String) -> PhysicalUnit? {
        exactNames[word] ?? wordNames[word.lowercased()]
    }

    func convert(_ amount: Decimal, to target: PhysicalUnit) throws -> Decimal {
        guard dimension == target.dimension else { throw CalcError.typeMismatch }
        if self == target { return amount }
        if dimension == .temperature {
            return try Self.fromCelsius(toCelsius(amount), in: target)
        }
        return try DecimalMath.divide(amount * factor, target.factor)
    }

    /// `5 m * 4 m = 20 m²`: jednostka powierzchni odpowiadająca jednostce długości.
    var squared: PhysicalUnit? {
        guard dimension == .length else { return nil }
        return Self.all.first { $0.dimension == .area && $0.factor == factor * factor }
    }

    // MARK: - Temperatura (z przesunięciem, więc osobno)

    private func toCelsius(_ t: Decimal) throws -> Decimal {
        switch symbol {
        case "°F": try DecimalMath.divide((t - 32) * 5, 9)
        case "K": t - Decimal(string: "273.15")!
        default: t
        }
    }

    private static func fromCelsius(_ c: Decimal, in target: PhysicalUnit) throws -> Decimal {
        switch target.symbol {
        case "°F": try DecimalMath.divide(c * 9, 5) + 32
        case "K": c + Decimal(string: "273.15")!
        default: c
        }
    }

    // MARK: - Tabela jednostek

    private struct Entry {
        let unit: PhysicalUnit
        /// Z rozróżnianiem wielkości liter: `m`, `MB`, `K`.
        let exact: [String]
        /// Bez rozróżniania: `metrów`, `kilograms`.
        let words: [String]
    }

    private static func entry(_ symbol: String, _ dimension: Dimension, _ factor: String,
                              _ exact: [String], _ words: [String] = []) -> Entry {
        Entry(unit: PhysicalUnit(symbol: symbol, dimension: dimension, factor: Decimal(string: factor)!),
              exact: exact, words: words)
    }

    private static let entries: [Entry] = [
        // Długość (metr)
        entry("mm", .length, "0.001", ["mm"], ["milimetr", "milimetry", "milimetrów", "milimetrow", "millimeter", "millimeters", "millimetre"]),
        entry("cm", .length, "0.01", ["cm"], ["centymetr", "centymetry", "centymetrów", "centymetrow", "centymetrach", "centimeter", "centimeters", "centimetre"]),
        entry("dm", .length, "0.1", ["dm"], ["decymetr", "decymetry", "decymetrów", "decymetrow"]),
        entry("m", .length, "1", ["m"], ["metr", "metry", "metrów", "metrow", "metrach", "meter", "meters", "metre", "metres"]),
        entry("km", .length, "1000", ["km"], ["kilometr", "kilometry", "kilometrów", "kilometrow", "kilometrach", "kilometer", "kilometers", "kilometre"]),
        // `in` to słowo konwersji, więc cale tylko pełnym słowem.
        entry("cal", .length, "0.0254", [], ["cal", "cale", "cali", "calach", "inch", "inches"]),
        entry("ft", .length, "0.3048", ["ft"], ["foot", "feet", "stopa", "stopy", "stóp", "stop"]),
        entry("yd", .length, "0.9144", ["yd"], ["yard", "yards", "jard", "jardy", "jardów", "jardow"]),
        entry("mi", .length, "1609.344", ["mi"], ["mile", "miles", "mila", "mil", "milach"]),

        // Waga (kilogram)
        entry("mg", .mass, "0.000001", ["mg"], ["miligram", "miligramy", "miligramów", "miligramow"]),
        entry("g", .mass, "0.001", ["g"], ["gram", "gramy", "gramów", "gramow", "gramach", "grams"]),
        entry("dag", .mass, "0.01", ["dag", "dkg"], ["deko", "dekagram", "dekagramy", "dekagramów", "dekagramow"]),
        entry("kg", .mass, "1", ["kg"], ["kilo", "kilogram", "kilogramy", "kilogramów", "kilogramow", "kilogramach", "kilograms"]),
        entry("t", .mass, "1000", ["t"], ["tona", "tony", "ton", "tonach", "tonne", "tonnes"]),
        entry("oz", .mass, "0.028349523125", ["oz"], ["ounce", "ounces", "uncja", "uncje", "uncji"]),
        // „funt” to waluta (GBP), więc funt jako waga – tylko `lb`.
        entry("lb", .mass, "0.45359237", ["lb", "lbs"]),

        // Objętość (litr)
        entry("ml", .volume, "0.001", ["ml"], ["mililitr", "mililitry", "mililitrów", "mililitrow"]),
        entry("cl", .volume, "0.01", ["cl"]),
        entry("dl", .volume, "0.1", ["dl"]),
        entry("l", .volume, "1", ["l", "L"], ["litr", "litry", "litrów", "litrow", "litrach", "liter", "liters", "litre", "litres"]),
        entry("m³", .volume, "1000", ["m3", "m³"]),
        entry("cm³", .volume, "0.001", ["cm3", "cm³", "ccm"]),
        entry("gal", .volume, "3.785411784", ["gal"], ["gallon", "gallons", "galon", "galony", "galonów", "galonow"]),
        entry("szkl.", .volume, "0.25", [], ["szklanka", "szklanki", "szklanek", "szkl"]),
        entry("łyżki", .volume, "0.015", [], ["łyżka", "łyżki", "łyżek", "lyzka", "lyzki", "lyzek"]),
        entry("łyżeczki", .volume, "0.005", [], ["łyżeczka", "łyżeczki", "łyżeczek", "lyzeczka", "lyzeczki", "lyzeczek"]),
        entry("cup", .volume, "0.2365882365", ["cup", "cups"]),
        entry("tbsp", .volume, "0.01478676478125", ["tbsp"]),
        entry("tsp", .volume, "0.00492892159375", ["tsp"]),

        // Powierzchnia (metr kwadratowy)
        entry("mm²", .area, "0.000001", ["mm2", "mm²"]),
        entry("cm²", .area, "0.0001", ["cm2", "cm²"]),
        entry("m²", .area, "1", ["m2", "m²"]),
        entry("ar", .area, "100", [], ["ar", "ary", "arów", "arow"]),
        entry("ha", .area, "10000", ["ha"], ["hektar", "hektary", "hektarów", "hektarow", "hectare", "hectares"]),
        entry("km²", .area, "1000000", ["km2", "km²"]),
        entry("ft²", .area, "0.09290304", ["ft2", "ft²", "sqft"]),
        entry("ac", .area, "4046.8564224", ["ac"], ["acre", "acres", "akr", "akry", "akrów", "akrow"]),

        // Temperatura (przeliczana wzorami, nie współczynnikiem)
        entry("°C", .temperature, "1", ["°C", "C", "℃"], ["celsius", "celsjusz", "celsjusza"]),
        entry("°F", .temperature, "1", ["°F", "F"], ["fahrenheit", "fahrenheita"]),
        entry("K", .temperature, "1", ["K"], ["kelvin", "kelwin", "kelwina", "kelwinów", "kelwinow"]),

        // Dane (bajt). KB/MB/GB – po 1000, KiB/MiB/GiB – po 1024.
        entry("bit", .data, "0.125", [], ["bit", "bits", "bity", "bitów", "bitow"]),
        entry("B", .data, "1", ["B"], ["bajt", "bajty", "bajtów", "bajtow", "byte", "bytes"]),
        entry("KB", .data, "1000", ["KB", "kB"], ["kb"]),
        entry("MB", .data, "1000000", ["MB"], ["mb"]),
        entry("GB", .data, "1000000000", ["GB"], ["gb"]),
        entry("TB", .data, "1000000000000", ["TB"], ["tb"]),
        entry("KiB", .data, "1024", ["KiB"]),
        entry("MiB", .data, "1048576", ["MiB"]),
        entry("GiB", .data, "1073741824", ["GiB"]),
        entry("TiB", .data, "1099511627776", ["TiB"]),
    ]

    private static let all = entries.map(\.unit)

    private static let exactNames: [String: PhysicalUnit] = {
        var names: [String: PhysicalUnit] = [:]
        for entry in entries {
            for name in entry.exact { names[name] = entry.unit }
        }
        return names
    }()

    private static let wordNames: [String: PhysicalUnit] = {
        var names: [String: PhysicalUnit] = [:]
        for entry in entries {
            for word in entry.words { names[word.lowercased()] = entry.unit }
        }
        return names
    }()
}
