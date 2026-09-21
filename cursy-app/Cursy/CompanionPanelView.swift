//
//  CompanionPanelView.swift
//  Cursy
//
//  Native macOS menu-bar panel. AppKit provides vibrancy while SwiftUI
//  provides semantic SF typography, SF Symbols, and controls.
//

import AppKit
import AVFoundation
import SwiftUI

struct CompanionPanelView: View {
    @ObservedObject var companionManager: CompanionManager
    var onOpenHome: (() -> Void)? = nil

    private var isSpanish: Bool { companionManager.preferredLanguage == .spanish }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            nativeDivider

            VStack(alignment: .leading, spacing: 12) {
                summary

                if let onOpenHome {
                    Button(action: onOpenHome) {
                        Label(localized("Probar Home · Beta", "Try Home · Beta"), systemImage: "rectangle.topthird.inset.filled")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .pointerCursor()
                }

                settingsCard

                if !companionManager.allPermissionsGranted {
                    permissionsCard
                }

                if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                    startButton
                }

                if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                    feedbackButton
                }
            }
            .padding(14)

            nativeDivider
            footer
        }
        .frame(width: 336)
        .background {
            NativePopoverMaterial()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.locale, Locale(identifier: companionManager.preferredLanguage.localeIdentifier))
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Cursy")
                    .font(.headline)

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Button {
                NotificationCenter.default.post(name: .cursyDismissPanel, object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(localized("Cerrar", "Close"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var summary: some View {
        if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("Mantén presionado para hablar", "Hold to talk"))
                        .font(.subheadline.weight(.medium))
                    Text(localized("Control + Opción", "Control + Option"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if companionManager.allPermissionsGranted {
            Label(
                localized("Todo está listo para conocer a Cursy.", "Everything is ready to meet Cursy."),
                systemImage: "checkmark.circle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("Configura Cursy", "Set up Cursy"))
                    .font(.subheadline.weight(.semibold))
                Text(localized(
                    "Autoriza estas funciones para hablar con Cursy y recibir ayuda sobre tu pantalla.",
                    "Allow these features to talk with Cursy and get help with your screen."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow(icon: "rectangle.on.rectangle", title: localized("Compartir pantalla", "Share screen")) {
                Toggle(localized("Compartir pantalla", "Share screen"), isOn: $companionManager.isVisualContextEnabled)
                    .labelsHidden().toggleStyle(.switch)
            }
            Text(companionManager.visualContextNotice ?? localized(
                "Al soltar el atajo, envía a OpenAI la pantalla del puntero. Puede actualizarla dos veces si cambia, hasta 30 s y hasta 5 s después de señalar. Sin clics ni grabación permanente.",
                "On shortcut release, sends OpenAI the pointer’s display. May refresh twice if it changes, for up to 30 s and up to 5 s after pointing. No clicks or permanent recording."))
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)
            insetDivider
            settingRow(icon: "arrow.triangle.2.circlepath", title: localized("Actualizar indicación", "Refresh indication")) {
                Toggle(localized("Actualizar indicación", "Refresh indication"), isOn: $companionManager.isVisualRefreshEnabled)
                    .labelsHidden().toggleStyle(.switch)
            }
            insetDivider
            settingRow(icon: "scribble", title: localized("Contexto espacial · Beta", "Spatial context · Beta")) {
                Toggle(localized("Contexto espacial", "Spatial context"), isOn: $companionManager.isSpatialContextEnabled)
                    .labelsHidden().toggleStyle(.switch)
                    .disabled(!companionManager.isVisualContextEnabled)
            }
            Text(localized(
                "Mientras hablas, señala o rodea algo con el puntero, sin hacer clic. Envía la huella con la imagen actual al soltar; hasta 30 s, sin guardarla. Scroll o cambio de pantalla reinician la huella. Esc cancela.",
                "While speaking, point at or circle something without clicking. Sends the path with the current image on release; up to 30 s, never saved. Scrolling or changing displays resets the path. Esc cancels."))
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)
            insetDivider
            settingRow(icon: "globe", title: localized("Idioma", "Language")) {
                Picker("", selection: Binding(
                    get: { companionManager.preferredLanguage },
                    set: { companionManager.setPreferredLanguage($0) }
                )) {
                    ForEach(CursyLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .help(localized(
                    "Cursy responderá siempre en este idioma.",
                    "Cursy will always respond in this language."
                ))
            }

            insetDivider
            settingRow(icon: "scope", title: localized("Indicación", "Indication")) {
                Picker(localized("Estilo de indicación", "Indication style"), selection: $companionManager.preferredAnnotationStyle) {
                    ForEach(VisualAnnotationStyle.allCases) { style in
                        Text(style.title(spanish: isSpanish)).tag(style)
                    }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
                .help(localized("Estilo para la próxima indicación. También puedes pedir una figura por voz.",
                                "Style for the next indication. You can also request a shape by voice."))
            }
            if companionManager.visualAnnotation != nil {
                Button {
                    companionManager.clearDetectedElementLocation()
                } label: {
                    Label(localized("Quitar indicación", "Clear indication"), systemImage: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .padding(.bottom, 10)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            insetDivider
            VStack(alignment: .leading, spacing: 8) {
                TextField(localized("Objetivo de la conversación (opcional)", "Conversation objective (optional)"),
                          text: Binding(
                            get: { companionManager.conversationSession.objective ?? "" },
                            set: { companionManager.setConversationObjective($0) }))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(localized("Objetivo de la conversación", "Conversation objective"))
                Button(action: companionManager.startNewConversation) {
                    Label(localized("Nueva conversación", "New conversation"), systemImage: "plus.bubble")
                }
                .disabled(!companionManager.chatLibrary.canCreate)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .help(localized("Inicia otro chat temporal y detiene el turno actual. Los anteriores quedan en Home hasta cerrar Cursy.",
                                "Starts another temporary chat and stops the current turn. Earlier chats stay in Home until quitting Cursy."))
                if let notice = companionManager.conversationNotice {
                    Text(notice).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)

            if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                insetDivider

                settingRow(icon: "brain.head.profile", title: localized("Modelo de respaldo", "Fallback model")) {
                    Picker("", selection: Binding(
                        get: { companionManager.selectedModel },
                        set: { companionManager.setSelectedModel($0) }
                    )) {
                        Text("GPT-4.1").tag("gpt-4.1")
                        Text("GPT-4.1 mini").tag("gpt-4.1-mini")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }
        .background(cardBackground)
    }

    private func settingRow<Accessory: View>(
        icon: String,
        title: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.subheadline)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localized("PERMISOS", "PERMISSIONS"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11)
                .padding(.top, 10)
                .padding(.bottom, 5)

            permissionRow(
                icon: "mic",
                title: localized("Micrófono", "Microphone"),
                isGranted: companionManager.hasMicrophonePermission,
                action: requestMicrophonePermission
            )
            insetDivider
            permissionRow(
                icon: "hand.raised",
                title: localized("Accesibilidad", "Accessibility"),
                isGranted: companionManager.hasAccessibilityPermission,
                action: { _ = WindowPositionManager.requestAccessibilityPermission() },
                secondaryAction: {
                    WindowPositionManager.revealAppInFinder()
                    WindowPositionManager.openAccessibilitySettings()
                }
            )
            insetDivider
            permissionRow(
                icon: "rectangle.dashed.badge.record",
                title: localized("Grabación de pantalla", "Screen Recording"),
                isGranted: companionManager.hasScreenRecordingPermission,
                action: { _ = WindowPositionManager.requestScreenRecordingPermission() }
            )

            if companionManager.hasScreenRecordingPermission {
                insetDivider
                permissionRow(
                    icon: "eye",
                    title: localized("Contenido de pantalla", "Screen Content"),
                    isGranted: companionManager.hasScreenContentPermission,
                    action: companionManager.requestScreenContentPermission
                )
            }
        }
        .background(cardBackground)
    }

    private func permissionRow(
        icon: String,
        title: String,
        isGranted: Bool,
        action: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isGranted ? Color.secondary : Color.orange)
                .frame(width: 18)
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)

            if isGranted {
                Label(localized("Permitido", "Allowed"), systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if let secondaryAction {
                    Button(localized("Buscar app", "Find App"), action: secondaryAction)
                        .controlSize(.small)
                }
                Button(localized("Permitir", "Allow"), action: action)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        } else if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    private var startButton: some View {
        Button {
            companionManager.triggerOnboarding()
        } label: {
            Text(localized("Comenzar", "Get Started"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var feedbackButton: some View {
        Button {
            if let url = URL(string: "mailto:hello@hellocursy.com") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 14, weight: .medium))
                VStack(alignment: .leading, spacing: 1) {
                    Text(localized("Enviar comentarios", "Send Feedback"))
                        .font(.subheadline.weight(.medium))
                    Text(localized("Ideas, errores o sugerencias", "Ideas, bugs, or suggestions"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(11)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                NSApp.terminate(nil)
            } label: {
                Label(localized("Salir de Cursy", "Quit Cursy"), systemImage: "power")
            }
            .buttonStyle(.plain)
            Spacer()

            if companionManager.hasCompletedOnboarding {
                Button {
                    companionManager.replayOnboarding()
                } label: {
                    Label(localized("Repetir introducción", "Replay Intro"), systemImage: "play.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.48))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            }
    }

    private var nativeDivider: some View { Divider().opacity(0.75) }
    private var insetDivider: some View { Divider().padding(.leading, 38) }

    private var statusColor: Color {
        guard companionManager.isOverlayVisible else { return .secondary }
        switch companionManager.voiceState {
        case .idle: return .green
        case .listening: return .orange
        case .connecting, .processing, .responding: return .accentColor
        }
    }

    private var statusText: String {
        if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
            return localized("Configuración", "Setup")
        }
        if !companionManager.isOverlayVisible {
            return localized("Listo", "Ready")
        }
        switch companionManager.voiceState {
        case .idle: return localized("Activo", "Active")
        case .connecting: return localized("Preparando micrófono", "Preparing microphone")
        case .listening: return localized("Escuchando", "Listening")
        case .processing: return localized("Procesando", "Processing")
        case .responding: return localized("Respondiendo", "Responding")
        }
    }

    private func localized(_ spanish: String, _ english: String) -> String {
        isSpanish ? spanish : english
    }
}

private struct NativePopoverMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
    }
}
