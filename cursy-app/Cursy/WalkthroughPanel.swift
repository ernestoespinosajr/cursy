import SwiftUI

struct WalkthroughPanel: View {
    @ObservedObject var manager: CompanionManager
    @ObservedObject var coordinator: WalkthroughCoordinator
    @State private var showFollowingConsent = false
    @State private var showSaveConsent = false
    @State private var deletingGuideID: UUID?
    private var spanish: Bool { manager.preferredLanguage == .spanish }
    private func text(_ es: String, _ en: String) -> String { spanish ? es : en }
    private var request: String {
        let draft = manager.homeDrafts[manager.chatLibrary.selectedID, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        return draft.isEmpty ? manager.conversationSession.requests.last?.transcript ?? "" : draft
    }

    var body: some View {
        if manager.conversationSession.selectedText == nil {
            VStack(alignment: .leading, spacing: 10) {
                if let guide = coordinator.guide, guide.conversationID == manager.chatLibrary.selectedID {
                    HStack {
                        Label(text("Guía", "Guide"), systemImage: coordinator.isFollowing ? "eye" : "list.number")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(min(guide.completedCount + 1, guide.steps.count))/\(guide.steps.count)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if guide.status == .draft {
                        Text(guide.goal).font(.callout.weight(.medium)).lineLimit(3)
                    } else if let step = guide.currentStep, !guide.isTerminal {
                        Text(step.content.instruction).font(.callout).textSelection(.enabled)
                    }
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel(notice)
                    HStack(spacing: 12) {
                        if [.draft, .paused, .blocked].contains(guide.status) {
                            Button(text(guide.status == .draft ? "Empezar" : "Reanudar", guide.status == .draft ? "Start" : "Resume")) { coordinator.start() }
                        }
                        if guide.status == .active {
                            Button(text("Listo", "Done")) { coordinator.confirmCurrentStep() }
                            Button(text("Pausar", "Pause")) { coordinator.pause() }
                        }
                        if !guide.isTerminal {
                            Button(text("Terminar", "End")) { coordinator.cancel() }
                        }
                    }.font(.caption.weight(.medium)).buttonStyle(HomeControlStyle())
                    if guide.status == .active, !coordinator.isFollowing {
                        Button { showFollowingConsent = true } label: {
                            Label(text("Verificar mis pasos en pantalla…", "Verify my steps on screen…"), systemImage: "eye")
                                .font(.caption)
                        }.buttonStyle(HomeControlStyle())
                            .disabled(!manager.isVisualContextEnabled)
                    }
                    if !manager.isVisualContextEnabled, !guide.isTerminal {
                        Text(text("Las indicaciones visuales necesitan Compartir pantalla en Privacidad.",
                                  "Visual guidance needs Screen Sharing in Privacy.")).font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        if !coordinator.currentIsSaved {
                            Button(text("Guardar guía…", "Save guide…")) { showSaveConsent = true }
                        } else {
                            Label(text("Guardada en este Mac", "Saved on this Mac"), systemImage: "internaldrive")
                            Button(text("Eliminar…", "Delete…")) { deletingGuideID = guide.id }
                        }
                        if !guide.isTerminal, !request.isEmpty {
                            Button(text("Ajustar con mi mensaje", "Revise with my message")) { coordinator.revise(request: request) }
                                .disabled(coordinator.isPreparing)
                        }
                    }.font(.caption2).buttonStyle(HomeControlStyle())
                    if guide.isTerminal { createButton }
                } else {
                    createButton
                    if coordinator.isPreparing { Text(notice).font(.caption).foregroundStyle(.secondary) }
                }
                if !coordinator.savedGuides.isEmpty {
                    Menu(text("Guías guardadas", "Saved guides")) {
                        ForEach(coordinator.savedGuides, id: \.id) { saved in
                            Button(saved.goal) { manager.reopenGuide(saved) }
                            Button(text("Eliminar: ", "Delete: ") + saved.goal, role: .destructive) { deletingGuideID = saved.id }
                        }
                    }.font(.caption).menuStyle(.borderlessButton)
                }
                if coordinator.persistenceFailed {
                    Text(text("No pude leer o guardar la guía. No descarté el archivo anterior.",
                              "Could not read or save the guide. The previous file was not discarded."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.vertical, 6)
            .task { await coordinator.loadSavedGuides() }
            .confirmationDialog(text("Guardar solo esta guía", "Save only this guide"), isPresented: $showSaveConsent) {
                Button(text("Guardar en este Mac", "Save on this Mac")) { Task { await coordinator.saveCurrentGuide() } }
                Button(text("Seguir temporal", "Keep temporary"), role: .cancel) {}
            } message: {
                Text(text("Se guardan el objetivo, los pasos y el progreso hasta que elimines la guía. No se guardan capturas, audio ni otros chats. El archivo no tiene cifrado propio de Cursy; usa la protección de tu usuario de macOS. Al reabrir, el seguimiento queda pausado.",
                          "Saves the goal, steps and progress until you delete the guide. No screenshots, audio or other chats. The file has no Cursy-level encryption; it uses your macOS account protection. Reopened guides are paused."))
            }
            .confirmationDialog(text("Eliminar guía guardada", "Delete saved guide"), isPresented: Binding(
                get: { deletingGuideID != nil }, set: { if !$0 { deletingGuideID = nil } })) {
                Button(text("Eliminar", "Delete"), role: .destructive) {
                    if let id = deletingGuideID { Task { await coordinator.deleteSavedGuide(id) } }
                    deletingGuideID = nil
                }
            } message: {
                Text(text("Se elimina la copia local de Cursy. Las copias de seguridad del sistema no están bajo su control.",
                          "Deletes Cursy's local copy. System backups are not under Cursy's control."))
            }
            .confirmationDialog(text("Seguimiento de esta guía", "Follow this guide"), isPresented: $showFollowingConsent) {
                Button(text("Permitir seguimiento", "Allow following")) { coordinator.enableFollowing() }
                Button(text("Cancelar", "Cancel"), role: .cancel) {}
            } message: {
                Text(text("Cursy enviará capturas de la pantalla del puntero para verificar este paso y los siguientes. Hasta 5 minutos, 10 verificaciones por paso y 30 por guía. No se guardan imágenes ni audio. Oculta información sensible antes de permitirlo. Puedes pausar en cualquier momento.",
                          "Cursy will send screenshots of the pointer's display to verify this and subsequent steps. Up to 5 minutes, 10 checks per step and 30 per guide. Images and audio are not saved. Hide sensitive information first. You can pause at any time."))
            }
        }
    }

    private var createButton: some View {
        Button {
            manager.cancelCurrentInteraction()
            coordinator.prepare(request: request, conversationID: manager.chatLibrary.selectedID)
        } label: {
            Label(text("Guiarme paso a paso", "Guide me step by step"), systemImage: "list.number")
                .font(.caption.weight(.medium))
        }.buttonStyle(HomeControlStyle()).disabled(request.isEmpty || coordinator.isPreparing)
    }

    private var notice: String {
        switch coordinator.notice {
        case .preparing: return text("Preparando los pasos…", "Preparing steps…")
        case .ready: return coordinator.currentIsSaved
            ? text("Guía guardada. Tú realizas las acciones.", "Saved guide. You perform the actions.")
            : text("Guía temporal. Tú realizas las acciones.", "Temporary guide. You perform the actions.")
        case .locating: return text("Buscando el objetivo en la pantalla actual…", "Finding the target on the current screen…")
        case .following: return text("Observando este paso · puedes pausar cuando quieras.", "Observing this step · pause whenever you want.")
        case .paused: return text("En pausa. No estoy observando tu pantalla.", "Paused. I am not observing your screen.")
        case .unavailable: return text("No pude continuar. Puedes reintentar o seguir manualmente.", "Could not continue. Retry or continue manually.")
        case .uncertain: return text("No puedo confirmar el resultado. Reanuda y pulsa Listo si lo completaste.", "I can't confirm the result. Resume and press Done if you completed it.")
        case .nextStep: return text("¡Muy bien! Vamos al siguiente paso.", "Nicely done! Let's move to the next step.")
        case .completed: return text("¡Excelente! Completaste la guía.", "Excellent! You completed the guide.")
        case .cancelled: return text("Guía terminada.", "Guide ended.")
        case .limit: return text("Seguimiento en pausa: alcanzamos su límite. Puedes continuar manualmente.", "Following paused: its limit was reached. You can continue manually.")
        case .blocked(let reason): return reason
        }
    }
}
