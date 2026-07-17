# ComiVerse Mobile Design System

## 1. Product Direction

ComiVerse Mobile is the Android-first reader application for the ComiVerse comic platform. The mobile experience focuses on discovering comics, reading chapters, maintaining a personal library, receiving notifications, managing a reader profile, and upgrading to Premium. Administrative workflows for Admin, Moderator, Translator, Project Leader, and Author remain in the web portals unless a future requirement explicitly brings a small approval workflow to mobile.

The mobile interface must feel like the same product as the web application: editorial comic imagery, restrained dark surfaces, warm light surfaces, purple-pink brand accents, compact controls, and strong readability during long reading sessions. Do not redesign it as a generic Material demo.

## 2. Design Principles

1. Reading comes first. Comic artwork and chapter content receive the most screen space.
2. Keep repeated actions reachable with one hand and place primary navigation at the bottom.
3. Light and dark modes are equal products. Every surface, text color, divider, overlay, skeleton, scrollbar, and system bar must follow the active theme.
4. Use brand gradients only for high-priority actions, active states, Premium, and small identity details.
5. Prefer dense, scannable layouts over large marketing sections.
6. Use icons for familiar actions and add tooltips or semantic labels where meaning is not obvious.
7. Modals that contain forms, payments, destructive actions, OTP entry, or unsaved work must not close when tapping outside.

## 3. Brand Identity

- Product name: `ComiVerse`
- Logo treatment: compact square brand mark followed by the ComiVerse wordmark when space permits.
- Brand personality: modern, premium, energetic, community-driven, but calm enough for long reading sessions.
- Main visual signal: real comic covers and chapter artwork. Do not use abstract blobs, decorative orbs, or generic stock illustrations.
- Primary accent gradient: purple to pink.
- Secondary action accent: orange may appear at the end of the primary CTA gradient, matching the web login and action buttons.

## 4. Color Tokens

Never place literal theme colors directly inside screen widgets. Define these values in the Flutter theme or a `ThemeExtension` and consume semantic tokens.

### Dark Theme

| Token | Value | Usage |
| --- | --- | --- |
| `background` | `#07040D` | App background and chapter reader matte |
| `surface` | `#0D0919` | App bars, sheets, menus, main cards |
| `surfaceRaised` | `#151120` | Raised cards and dialogs |
| `surfaceSubtle` | `rgba(255,255,255,0.05)` | Inputs, secondary buttons, selected rows |
| `textPrimary` | `#F1F5F9` | Titles and primary values |
| `textSecondary` | `#CBD5E1` | Body copy and labels |
| `textMuted` | `#94A3B8` | Metadata and helper text |
| `textDisabled` | `#64748B` | Disabled states |
| `border` | `rgba(255,255,255,0.08)` | Standard border and divider |
| `borderSubtle` | `rgba(255,255,255,0.04)` | Low-emphasis separators |
| `overlay` | `rgba(0,0,0,0.68)` | Modal barrier |

### Light Theme

| Token | Value | Usage |
| --- | --- | --- |
| `background` | `#FAF6F0` | Warm app background |
| `readerBackground` | `#F8F5F0` | Chapter reader and featured comic band |
| `surface` | `#FFFFFF` | App bars, sheets, menus, main cards |
| `surfaceRaised` | `#FFFFFF` | Dialogs and elevated panels |
| `surfaceSubtle` | `#F5F1EC` | Inputs, secondary buttons, list rows |
| `textPrimary` | `#182235` | Titles and primary values |
| `textSecondary` | `#475569` | Body copy and labels |
| `textMuted` | `#64748B` | Metadata and helper text |
| `textDisabled` | `#94A3B8` | Disabled states |
| `border` | `rgba(99,87,78,0.16)` | Standard border and divider |
| `borderSubtle` | `rgba(99,87,78,0.10)` | Low-emphasis separators |
| `overlay` | `rgba(44,29,17,0.45)` | Modal barrier |

### Shared Brand And Status Colors

| Token | Value |
| --- | --- |
| `brandPurple` | `#A855F7` |
| `brandPurpleHover` | `#C084FC` dark / `#7C3AED` light |
| `brandPink` | `#EC4899` |
| `brandOrange` | `#FF6B35` |
| `brandOrangeBright` | `#FF9416` |
| `success` | `#10B981` |
| `warning` | `#F59E0B` |
| `error` | `#EF4444` |
| `info` | `#06B6D4` |
| `rating` | `#FBBF24` |

Primary CTA gradient: `#A855F7 -> #EC4899`. The orange extension `#FF6B35 -> #FF9416` may be used for authentication or purchase CTAs, but not on every button.

## 5. Typography

- Primary family: `Outfit`.
- Fallback: Android system sans-serif when the font is unavailable.
- Editorial family: `Playfair Display`, used only for a featured comic title or a major editorial heading. Do not use it inside forms, tabs, dialogs, or compact cards.
- Display title: 28px, weight 700, line height 34px.
- Screen title: 22px, weight 700, line height 28px.
- Section title: 18px, weight 700, line height 24px.
- Card title: 15px, weight 600 or 700, line height 20px.
- Body: 14px, weight 400, line height 21px.
- Label: 12px, weight 600, line height 16px.
- Metadata: 11px, weight 500, line height 15px.
- Button: 14px, weight 700.
- Do not scale font size from viewport width. Support Android text scaling without clipping.
- Letter spacing is `0`; uppercase labels may use at most `0.5px`.

## 6. Spacing, Shape, And Elevation

- Base spacing unit: 4px.
- Standard screen gutter: 16px; use 20px on tablets.
- Common vertical gaps: 8px, 12px, 16px, 24px, 32px.
- Minimum touch target: 48x48dp.
- Card radius: 8px.
- Input, button, dropdown, and dialog radius: 8px.
- Comic cover radius: 6px.
- Chips and status badges may use a pill radius.
- Do not nest cards inside cards. Use dividers, spacing, or full-width bands inside a card.
- Dark shadow: `0 10 30 rgba(0,0,0,0.35)`.
- Light shadow: `0 8 24 rgba(44,29,17,0.08)`.
- Borders are preferred over heavy elevation for ordinary cards.

## 7. Main Navigation

Use a fixed Material 3 `NavigationBar` with five destinations:

1. Home
2. Explore
3. Library
4. Notifications
5. Profile

Use outlined icons for inactive destinations and filled icons for the active destination. The active indicator uses a low-opacity purple surface, not a large gradient. Ranking is accessible from Home and Explore rather than taking a permanent navigation slot.

Secondary navigation rules:

- Use a leading back arrow on detail, reader, authentication recovery, and settings screens.
- Preserve the selected bottom destination when returning from comic detail.
- Opening a chapter hides the bottom navigation to maximize reading space.
- Authentication screens do not show bottom navigation.

## 8. Screen Specifications

### Authentication

- Screens: Sign In, Sign Up, Verify Email OTP, Forgot Password, Reset Password.
- Use a compact ComiVerse brand header and a single form column.
- Inputs have persistent labels above the field; errors appear directly below the related field without refreshing or clearing the form.
- Password fields include a trailing visibility icon.
- Remember Me uses a checkbox vertically centered with its label.
- Sign In and Sign Up use the primary gradient button.
- Google authentication is a bordered secondary button.
- OTP uses six stable single-character cells, numeric keyboard, auto-advance, paste support, resend countdown, and loading/error states.
- Forgot Password always shows a neutral success message so the UI does not reveal whether an email exists.

### Home

- Top app bar: compact ComiVerse identity, search action, theme action, and avatar.
- First viewport: featured comic band with readable title, genres, rating, chapter count, cover, and one primary `Read now` action. Keep a hint of the next section visible.
- Sections: Continue Reading, Recommended, Trending, and New Chapters.
- Use horizontal cover rails for discovery and a denser vertical list for updates.
- Continue Reading cards include current chapter and progress.
- Avoid oversized empty hero space.

### Explore And Search

- Search field remains near the top and supports title, author, and genre queries.
- Filters open in a modal bottom sheet: genres, status, language, sort order.
- Active filters appear as removable chips.
- Results use a two-column cover grid on phones and a wider adaptive grid on tablets.
- Each result shows cover, title, primary genre, latest chapter, and optional rating.

### Ranking

- Use segmented controls for Daily, Weekly, and Monthly.
- The top three items may be visually emphasized, but all ranking rows must remain easy to compare.
- Rank, cover, title, genre, rating, views, and movement indicator are visible.

### Comic Detail

- Use the real cover and comic information as the first visual signal.
- Header may collapse from artwork into a standard app bar while scrolling.
- Show title, author, genres, rating, views, status, synopsis, and chapter count.
- Primary actions: Read/Continue and Save to Library.
- Secondary actions: Like, Share, and Download when Premium permits it.
- Tabs: Chapters and Comments.
- Chapter rows show number/title, date, views, read status, and Premium lock when applicable.
- The chapter list uses theme-aware surfaces and dividers; no black scrollbar or black panel in light mode.

### Chapter Reader

- Hide bottom navigation and keep controls minimal.
- Default mode is vertical continuous scroll with full-width comic pages.
- Dark reader matte: `#07040D`; light reader matte: `#F8F5F0`.
- The image wrapper, loading shimmer, top controls, chapter dropdown, bottom controls, and system bars must use reader theme tokens. Never hard-code a black wrapper.
- Top controls: back, compact comic/chapter title, previous, chapter selector, next.
- Auto-hide reader controls while scrolling down and reveal them when scrolling up or tapping once.
- Provide Back to Top and next/previous chapter actions at the end.
- Keep comic image aspect ratio and never crop chapter pages.
- Loading should use skeleton or progress indicators without changing page width.
- Offline and security messages use semantic banners without covering comic content.

### Library

- Tabs: Saved, Favorites, and History.
- Allow sorting by recently read, recently added, title, and latest update.
- Cards show cover, title, chapter progress, latest chapter, and status.
- Destructive removal requires confirmation or an undo snackbar.
- Empty states contain one concise message and one relevant action.

### Notifications

- Group by Today, Earlier This Week, and Older.
- Basic notification types: new chapter, assigned translation task, moderation result, comment/reply, library update, Premium/payment, system broadcast, and account security.
- Use an icon plus color accent for type; do not color the entire row.
- Unread rows use a subtle purple tint and a small unread dot.
- Support Mark all as read and deep-link to the relevant screen.

### Profile And Settings

- Header includes avatar upload, display name, username, role badge, and member date.
- Sections: Personal Information, Change Password, Theme, Language, Premium Plan, Downloads, Notification Preferences, Privacy, and Help.
- Avatar supports JPG/PNG, preview, upload progress, validation, and error feedback.
- Avatar menu includes Profile, Reading History, Favorites, Settings, and Sign Out.
- Sign Out always opens a confirmation dialog. The dialog cannot be dismissed by tapping outside.

### Premium Upgrade

- On phones, use a full-screen route or vertically scrollable bottom sheet instead of three compressed columns.
- Plans: Free, Premium Monthly, Premium Yearly.
- Clearly show current plan, recommended plan, price, billing period, benefits, and purchase CTA.
- Plan names, prices, and benefits come from the backend system settings API; do not hard-code commercial data.
- Purchase confirmation and payment errors stay visible until explicitly dismissed.

## 9. Reusable Components

- `ComiVerseAppBar`
- `ComiVerseBottomNavigation`
- `ComicCoverCard`
- `ComicListRow`
- `ChapterRow`
- `ContinueReadingCard`
- `GenreChip`
- `StatusBadge`
- `RatingLabel`
- `SearchField`
- `FilterBottomSheet`
- `ThemeIconButton`
- `AvatarMenu`
- `PrimaryGradientButton`
- `SecondaryButton`
- `ConfirmDialog`
- `InlineFieldError`
- `EmptyState`
- `ErrorState`
- `ComicSkeleton`
- `NotificationRow`
- `PlanCard`

Every reusable component must define normal, pressed, focused, disabled, loading, error, selected, and light/dark states where applicable.

## 10. Interaction And Feedback

- Standard transition: 180–250ms with ease-out.
- Page navigation uses restrained platform transitions.
- Buttons show immediate pressed feedback and remain dimensionally stable while loading.
- Use snackbars for non-blocking success and undo actions.
- Use dialogs for destructive actions, sign out, purchase confirmation, and irreversible changes.
- Prevent duplicate submissions while an API call is running.
- Pull to refresh is allowed on Home, Explore, Library, Ranking, and Notifications.
- Preserve scroll position when returning from comic detail or reader.
- Respect reduced-motion settings.

## 11. Loading, Empty, Error, And Offline States

- Use skeletons shaped like the final content; avoid layout shifts.
- Field validation remains inline and persists until the value changes or becomes valid.
- API errors include a short human-readable message and Retry when retry is meaningful.
- Offline mode uses a compact banner and cached content where available.
- Do not use browser-style alerts.
- Do not refresh or replace the whole screen for a form validation error.

## 12. Accessibility

- Minimum text contrast: WCAG AA.
- Minimum touch target: 48dp.
- Every icon-only action has a semantic label.
- Do not communicate status using color alone.
- Support screen readers, Android font scaling, and landscape orientation for the reader.
- Keep focus order logical in forms, OTP input, dialogs, and bottom sheets.
- System status/navigation bar icon brightness must match the active theme.

## 13. Responsive Rules

- Phone: 320–599dp, 16dp gutter, two-column comic grid.
- Large phone/small tablet: 600–839dp, 20dp gutter, three or four-column grid.
- Tablet: 840dp and above, optional navigation rail and master-detail layouts.
- Limit readable text width to about 680dp on tablets.
- Fixed-format elements must use stable constraints so labels, loading states, and badges cannot resize surrounding layout.
- No horizontal overflow at 320dp width.

## 14. Flutter Implementation Guidance

- Keep all colors and component defaults in `lib/src/theme/app_theme.dart` or dedicated `ThemeExtension` classes.
- Replace the current light background `#FFF8FF` with the web-aligned warm palette defined above.
- Reduce the current 14–18px general radii to the 8px system; reserve pills for chips and badges.
- Use `Theme.of(context).colorScheme` and semantic extensions instead of `const Color(...)` inside screens, except for shared brand/status constants.
- Persist `ThemeMode` per signed-in user and fall back to the device preference for first launch.
- Use `SafeArea`, keyboard-aware forms, and `MediaQuery` text scaling.
- Keep API models and visual components separate. Backend failures must not be represented as design state inside model classes.
- Commercial plan data, user profile data, notifications, comic metadata, and chapter lists come from APIs.

## 15. AI Generation Guardrails

- Build the real reader application screens, not a landing page.
- Do not invent extra colors outside this token set without a documented semantic reason.
- Do not place text over comic artwork unless a contrast overlay guarantees readability.
- Do not use nested cards, oversized rounded containers, decorative gradient backgrounds, or empty marketing copy.
- Do not use emoji as interface icons; use Material or Lucide-style icons.
- Do not show management dashboards for non-reader roles in the first mobile release.
- Do not hard-code black or white in screen widgets when a semantic theme token exists.
- Keep terminology consistent with the web application: Home, Explore, Ranking, Library, Favorites, Reading History, Notifications, Profile, Premium, Chapter, and Sign Out.

## 16. Definition Of Done

A mobile screen is complete only when it:

- Matches the ComiVerse web color and typography direction.
- Works in both light and dark modes without hard-coded theme leaks.
- Handles loading, empty, error, offline, disabled, and success states.
- Works at 320dp phone width and on a tablet layout.
- Has no clipped text, overlap, horizontal overflow, or layout jump.
- Uses accessible labels and touch targets.
- Connects to the intended backend API or clearly uses isolated mock data during development.

