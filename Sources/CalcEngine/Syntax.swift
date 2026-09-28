import Foundation

enum UnaryOperator {
    case negate
    case bitNot
}

enum BinaryOperator {
    case add, subtract, multiply, divide, modulo, power
    case bitAnd, bitOr, bitXor, shiftLeft, shiftRight
}

indirect enum Expression {
    case number(Decimal, Radix)
    case date(year: Int, month: Int, day: Int)
    case variable(String)
    /// Liczba z jednostką: `5 USD`, `$5`, `3 dni`.
    case quantity(Expression, Quantity)
    case unary(UnaryOperator, Expression)
    case binary(BinaryOperator, Expression, Expression)
    case call(String, [Expression])
}

enum Statement {
    case expression(Expression, conversion: Conversion?)
    case assignment(name: String, Expression, conversion: Conversion?)
}
