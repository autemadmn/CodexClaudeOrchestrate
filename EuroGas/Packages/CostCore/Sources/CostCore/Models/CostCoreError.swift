import Foundation

/// Errores producidos al validar las entradas del núcleo de costes y reparto.
public enum CostCoreError: Error, Equatable, LocalizedError {
    case nonPositivePrice
    case nonPositiveConsumption
    case nonPositiveFactor
    case invalidDistance
    case participantCountOutOfRange(Int)
    case passengersOnlyWithoutPassengers
    case negativeTotal

    public var errorDescription: String? {
        switch self {
        case .nonPositivePrice:
            return "El precio unitario debe ser mayor que 0; introduce un precio válido."
        case .nonPositiveConsumption:
            return "El consumo debe ser mayor que 0; introduce un consumo válido."
        case .nonPositiveFactor:
            return "El factor de consumo debe ser mayor que 0; introduce un factor válido."
        case .invalidDistance:
            return "La distancia debe ser un valor finito mayor o igual que 0; introduce una distancia válida."
        case let .participantCountOutOfRange(count):
            return "El número de participantes recibido es \(count); introduce un valor entre 1 y 8."
        case .passengersOnlyWithoutPassengers:
            return "La regla de pasajeros requiere al menos un pasajero; añade un pasajero o elige otra regla."
        case .negativeTotal:
            return "El total no puede ser negativo; introduce un total cero o positivo."
        }
    }
}
