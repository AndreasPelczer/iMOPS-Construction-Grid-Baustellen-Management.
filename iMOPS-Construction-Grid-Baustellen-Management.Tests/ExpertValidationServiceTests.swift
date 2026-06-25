import Foundation
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ExpertValidationServiceTests {

    @Test func anonymizedRequestEnthaeltNurBeschreibungUndEinheit() {
        let request = ExpertValidationService.prepareAnonymizedRequest(
            for: LVDraftPosition(
                bezeichnung: "Mutterboden abtragen und seitlich lagern",
                einheit: "m3"
            )
        )

        #expect(request.contains("Mutterboden abtragen"))
        #expect(request.contains("m3"))
        #expect(!request.localizedCaseInsensitiveContains("bauherr"))
        #expect(!request.localizedCaseInsensitiveContains("adresse"))
        #expect(!request.localizedCaseInsensitiveContains("projekt"))
        #expect(!request.localizedCaseInsensitiveContains("preis"))
        #expect(!request.localizedCaseInsensitiveContains("menge"))
    }

    @Test func mutterbodenSchlaegtBaugrubeVor() {
        let proposal = ExpertValidationService.proposeKG(
            for: LVDraftPosition(
                bezeichnung: "Mutterboden abtragen und seitlich lagern",
                einheit: "m3"
            )
        )

        #expect(proposal?.suggestedKG == "311")
        #expect((proposal?.confidence ?? 0) > 0.8)
        #expect(proposal?.source == "local")
    }

    @Test func bauzaunSchlaegtSicherungVor() {
        let proposal = ExpertValidationService.proposeKG(
            for: LVDraftPosition(
                bezeichnung: "Bauzaun Stahlrahmen mobil aufstellen",
                einheit: "m"
            )
        )

        #expect(proposal?.suggestedKG == "393")
    }

    @Test func unbekannterTextBleibtOhneVorschlag() {
        let proposal = ExpertValidationService.proposeKG(
            for: LVDraftPosition(
                bezeichnung: "Freier Text ohne fachlichen Treffer",
                einheit: "Stück"
            )
        )

        #expect(proposal == nil)
    }
}
