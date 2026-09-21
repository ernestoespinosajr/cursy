//
//  CursyLanguage.swift
//  Cursy
//
//  User-selected interface and response language.
//

import Foundation

enum CursyLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .spanish: return "es-419"
        case .english: return "en-US"
        }
    }

    var realtimeInstructions: String {
        switch self {
        case .spanish:
            return """
            LANGUAGE: Always understand and answer in natural, neutral Latin American Spanish. \
            Do not switch to English even when the user uses English technical terms. Preserve familiar \
            product names and technical terms, but keep the explanation and spoken response in Spanish. \
            Use clear Spanish pronunciation.
            """
        case .english:
            return """
            LANGUAGE: Always understand and answer in natural American English. Do not switch to Spanish \
            even if the user includes Spanish words. Preserve proper names and technical terms, but keep \
            the explanation and spoken response in English.
            """
        }
    }

    var legacyPromptInstruction: String {
        switch self {
        case .spanish:
            return "Answer entirely in natural, neutral Latin American Spanish. Keep technical product names when useful, but never switch the explanation to English."
        case .english:
            return "Answer entirely in natural American English. Keep proper names and technical terms when useful, but never switch the explanation to Spanish."
        }
    }
}
