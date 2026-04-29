import SwiftUI

// MARK: - View

/// Handle-prefix search. The query field is the only input; tapping a
/// result pushes `UserProfileView(uid:)` onto the surrounding navigation
/// stack. Auth and friend-graph deps live in the environment — this
/// view only resolves `currentUid` to filter self out of results.
struct FriendSearchView: View {

    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm: FriendSearchViewModel
    @FocusState private var queryFocused: Bool

    init(currentUid: String?, userDirectory: any UserSearching) {
        _vm = StateObject(
            wrappedValue: FriendSearchViewModel(
                currentUid: currentUid,
                userDirectory: userDirectory
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: SearchLayout.outerSpacing) {
                searchField
                resultsArea
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SearchLayout.horizontalPadding)
            .padding(.top, SearchLayout.topPadding)
        }
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { queryFocused = true }
    }

    // MARK: - Search field

    private var searchField: some View {
        BlipTextField(
            label: Copy.fieldLabel,
            placeholder: Copy.fieldPlaceholder,
            text: $vm.query,
            isFocused: $queryFocused,
            font: .blip(size: SearchLayout.fieldFontSize, weight: .medium),
            submitLabel: .search
        )
    }

    // MARK: - Results router

    @ViewBuilder
    private var resultsArea: some View {
        if vm.query.isEmpty {
            hintState
        } else if vm.isSearching && vm.results.isEmpty {
            searchingState
        } else if vm.results.isEmpty && vm.lastError != nil {
            errorState
        } else if vm.results.isEmpty {
            noResultsState
        } else {
            resultsList
        }
    }

    private var hintState: some View {
        Text(Copy.hint)
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textTertiary)
            .padding(.top, SearchLayout.hintTopPadding)
    }

    private var searchingState: some View {
        HStack {
            Spacer()
            ProgressView().tint(BlipColor.textSecondary)
            Spacer()
        }
        .padding(.top, SearchLayout.hintTopPadding)
    }

    private var noResultsState: some View {
        Text(Copy.noResults)
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textTertiary)
            .padding(.top, SearchLayout.hintTopPadding)
    }

    private var errorState: some View {
        Text(Copy.searchFailed)
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.error)
            .padding(.top, SearchLayout.hintTopPadding)
    }

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: SearchLayout.rowSpacing) {
                ForEach(vm.results) { result in
                    NavigationLink {
                        UserProfileView(uid: result.id)
                    } label: {
                        UserResultRow(handle: result.handle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("open profile for @\(result.handle)")
                }
            }
            .padding(.top, SearchLayout.listTopPadding)
        }
    }
}

// MARK: - Result row

private struct UserResultRow: View {
    let handle: String

    var body: some View {
        HStack(spacing: SearchLayout.rowInnerSpacing) {
            AvatarView(
                initials: Self.initials(for: handle),
                hasPosted: false,
                size: SearchLayout.avatarSize
            )
            Text("@\(handle)")
                .font(.blip(size: SearchLayout.handleFontSize, weight: .medium))
                .foregroundStyle(BlipColor.textPrimary)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(BlipColor.textTertiary)
        }
        .padding(.horizontal, SearchLayout.rowHPadding)
        .frame(minHeight: SearchLayout.rowMinHeight)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: SearchLayout.rowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SearchLayout.rowCornerRadius, style: .continuous)
                .stroke(BlipColor.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private static func initials(for handle: String) -> String {
        let trimmed = handle.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "_", with: "")
        return String(trimmed.prefix(2)).uppercased()
    }
}

// MARK: - Layout constants

private enum SearchLayout {
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 12
    static let outerSpacing: CGFloat = 16
    static let listTopPadding: CGFloat = 8
    static let hintTopPadding: CGFloat = 12

    static let fieldFontSize: CGFloat = 18

    static let rowSpacing: CGFloat = 8
    static let rowInnerSpacing: CGFloat = 12
    static let rowHPadding: CGFloat = 14
    static let rowMinHeight: CGFloat = 52  // exceeds 44pt HIG min
    static let rowCornerRadius: CGFloat = 12
    static let avatarSize: CGFloat = 32
    static let handleFontSize: CGFloat = 16
}

// MARK: - Copy (Lane A)

private enum Copy {
    static let title = "Find friends"
    static let fieldLabel = "handle"
    static let fieldPlaceholder = "@handle"
    static let hint = "Search for friends by handle."
    static let noResults = "No one found."
    static let searchFailed = "Search failed — check your connection."
}
