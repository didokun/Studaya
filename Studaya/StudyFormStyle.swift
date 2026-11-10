import SwiftUI

/// Keep native editing, menus and Dynamic Type, with comfortable touch targets.
struct StudyTextFieldStyle: TextFieldStyle {
    var boxed = false
    func _body(configuration: TextField<Self._Label>) -> some View {
        StudyTextInput(field: configuration, boxed: boxed)
    }
}

private struct StudyTextInput<Label: View>: View {
    let field: TextField<Label>
    let boxed: Bool
    @FocusState private var editing: Bool
    var body: some View {
        field
            .focused($editing)
            .font(.body)
            .frame(minHeight: 44, alignment: .leading)
            .padding(.horizontal, boxed ? 14 : 0)
            .padding(.vertical, boxed ? 4 : 0)
            .background {
                if boxed {
                    RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground))
                }
            }
            .overlay {
                if boxed {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator).opacity(0.5))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = true }
    }
}

private struct StudyMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator).opacity(0.5)) }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct StudyIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    /// Standalone menu pickers need their own full-width label and hit area.
    func studyMenu(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Menu {
                self.labelsHidden().pickerStyle(.inline)
            } label: {
                HStack(spacing: 12) {
                    Text(value).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down").font(.body.weight(.medium))
                }
            }
            .buttonStyle(StudyMenuButtonStyle())
            .accessibilityLabel(title)
            .accessibilityValue(value)
        }
    }
}
