//
//  PHTVAppIntentsLinkAnchor.swift
//  PHTV
//
//  Ensures AppIntents framework is linked so metadata extraction
//  does not emit "No AppIntents.framework dependency found".
//

#if canImport(AppIntents)
import AppIntents

enum PHTVAppIntentsLinkAnchor {
    // Force at least one symbol reference so the framework is autolinked.
    static let dialogSeed = IntentDialog("PHTV")
}
#endif

