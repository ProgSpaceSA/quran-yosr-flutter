# QuranER — Feature Requirements

# Quran App Development Document

## App Name: القرآن الكريم يسر

## Product Direction: Simple Quran Reading, Daily Wird, and Habit Building

---

## Status Legend

| Mark | Meaning |
|---|---|
| `[x]` | Done |
| `[~]` | Partial / In progress |
| `[ ]` | Not started |

---

## Overall Progress by Phase

| Phase | Status |
|---|---|
| Phase 1 — Stability and Reading Core | ✅ Done |
| Phase 2 — Daily Wird and Habit System | ⬜ Not started |
| Phase 3 — Organization | ⬜ Not started |
| Phase 4 — Memorization | ⬜ Not started |
| Phase 5 — Ramadan Features | ⬜ Not started |
| Phase 6 — Advanced Features | ⬜ Not started |

---

# 1. Product Overview

The app is a simple, calm, and focused Quran application designed to help users read the Quran consistently, continue from where they stopped, build a daily wird habit, and prepare for Ramadan through a stable daily program.

The app should not feel like a generic book reader only. It should feel like an interactive Quran companion with reading progress, bookmarks, reminders, memorization tools, and habit tracking.

---

# 2. Main Goals

## Primary Goals

- [x] Improve the Quran reading experience.
- [x] Fix and enhance reading-position management.
- [ ] Help users build a daily Quran habit.
- [ ] Support daily wird and khatmah planning.
- [ ] Add memorization and revision tools.
- [x] Keep the app simple, clean, and distraction-free.
- [ ] Prepare the foundation for future sync, Ramadan plans, tafsir, and advanced features.

---

# 3. Core Principles

## Simplicity First

The app should remain lightweight and easy to use. Avoid unnecessary complexity.

## Local-First

Most user data should be stored locally first:

- [x] Reading position
- [ ] Wird target
- [ ] Streaks
- [ ] Bookmarks
- [ ] Notes
- [x] Preferences *(font size, theme mode)*
- [ ] Memorization progress

User accounts and cloud sync can come later.

## Quran-Focused

The reading screen should remain the heart of the app.

## Habit-Oriented

The app should encourage consistency without making the user feel guilty or overwhelmed.

---

# 4. Core Reading Improvements — 🔄 Partial

## 4.1 Reading Position Management — 🔄 Partial

The app must accurately save and restore the user's reading position.

### Requirements

- [x] Save last opened surah.
- [x] Save last opened ayah.
- [ ] Save last opened page if page mode exists.
- [x] Save scroll position inside the reading screen. *(key-based anchor + sub-pixel offset)*
- [x] Restore exact position when reopening the app.
- [x] Restore position after app pause/resume.
- [~] Restore position after navigating away and returning. *(works for main reading; multiple typed positions not supported yet)*
- [x] Avoid jumping to the wrong ayah after refresh or state update.

### Acceptance Criteria

- [x] User closes the app on a specific ayah and returns to the same ayah.
- [x] User switches between surahs and returns without losing position.
- [x] User backgrounding the app does not reset reading state.

---

## 4.2 Returning Mechanism — ⬜ Not started

Add a clear "Continue Reading" mechanism.

### Requirements

- [ ] Show "Continue Reading" on home screen.
- [ ] Display last surah and ayah.
- [ ] One tap returns to exact position.
- [ ] Support multiple auto-saved reading positions later.

### Example

Continue Reading
Surah Al-Baqarah, Ayah 120

---

## 4.3 Surah / Juz / Page Switching Optimization — ✅ Done

Improve navigation speed and reliability.

### Requirements

- [x] Fast switching between surahs.
- [x] Fast switching between juz.
- [x] Fast page navigation if Mushaf page mode is enabled.
- [x] Avoid blank loading delays.
- [x] Avoid scroll reset bugs.
- [ ] Cache recently opened sections locally if needed.

---

## 4.4 Page Loading Performance — ✅ Done

### Requirements

- [x] Reduce initial loading time.
- [x] Lazy-load heavy data if needed.
- [x] Keep Quran text available offline.
- [x] Avoid unnecessary re-renders.
- [x] Optimize long list rendering.
- [x] Use indexed access for surah, ayah, juz, and page lookup.

---

## 4.5 Dark Mode — ✅ Done

### Requirements

- [x] Improve dark mode readability.
- [x] Avoid pure black/pure white contrast fatigue.
- [x] Save selected mode.
- [ ] Support system default if possible.
- [x] Ensure ayah numbers, controls, and highlights remain clear.

---

## 4.6 Font Size Controller — 🔄 Partial

### Requirements

- [x] Add font size control. *(pinch-to-zoom implemented)*
- [x] Save user-selected size.
- [x] Apply font size instantly.
- [x] Keep layout stable after changing font size.
- [ ] Support at least small, medium, large, and extra-large preset levels. *(only continuous pinch scale; no discrete presets)*

---

## 4.7 Save Reading Preferences / Session — 🔄 Partial

### Requirements

Save locally:

- [x] Font size
- [x] Theme mode
- [x] Last reading position
- [ ] Last selected tab/mode
- [ ] Preferred reading mode
- [ ] Selected daily wird settings

---

# 5. Daily Reading Features — ⬜ Not started

## 5.1 Daily Reading Program

A daily reading program helps the user build a fixed Quran habit.

### Requirements

- [ ] User can create a daily Quran reading target.
- [ ] User can choose based on:

  - [ ] Number of pages
  - [ ] Number of ayahs
  - [ ] Time duration
  - [ ] Khatmah goal
- [ ] The app shows today's reading target.
- [ ] User can mark the target as completed.
- [ ] The app saves daily completion history.

---

## 5.2 Daily Wird Target

The daily wird target should be private and local by default.

### Requirements

- [ ] User can set a daily target.
- [ ] No account required.
- [ ] Data saved locally.
- [ ] User can edit target anytime.
- [ ] App should show progress for today.

### Target Types

- [ ] Read X pages per day
- [ ] Read X ayahs per day
- [ ] Read for X minutes per day
- [ ] Finish Quran by a target date

---

## 5.3 Khatmah Before Ramadan Plan

The app should allow users to prepare for Ramadan by building a daily Quran habit before Ramadan.

### Requirements

- [ ] User selects target date: before Ramadan.
- [ ] App calculates required daily reading.
- [ ] App supports flexible recovery if user misses days.
- [ ] Show progress toward khatmah goal.
- [ ] Avoid making user feel behind aggressively.

### Tone

Use encouraging language:

* "You can continue today."
* "Small progress still counts."
* "Your plan has been adjusted."

Avoid harsh language:

* "You failed."
* "You are late."
* "You missed your goal."

---

## 5.4 Progress Tracking

### Requirements

Track:

- [ ] Daily completion
- [ ] Pages read
- [ ] Ayahs read
- [ ] Current khatmah progress
- [ ] Reading streak
- [ ] Missed days
- [ ] Recovery status

---

## 5.5 Daily Reminder

### Requirements

- [ ] User can enable/disable reminders.
- [ ] User can select reminder time.
- [ ] Reminder should mention the daily wird gently.
- [ ] Reminder should open today's reading target.

### Example Notification

Title: Continue your daily wird
Body: A small reading today keeps your Quran habit alive.

---

## 5.6 Reading Streak

### Requirements

- [ ] Count consecutive days completed.
- [ ] Show streak on dashboard.
- [ ] Streak should be motivating, not stressful.
- [ ] Allow grace/recovery logic later.

---

## 5.7 Missed-Day Recovery

If the user misses a day, the app should adjust the plan gently.

### Requirements

- [ ] Redistribute missed reading over coming days.
- [ ] Offer lighter recovery option.
- [ ] Avoid overwhelming the user with a large target.
- [ ] Let user skip recovery and continue normally.

### Recovery Options

- [ ] Add missed amount over next 3 days.
- [ ] Add missed amount over next 7 days.
- [ ] Ignore missed day and continue.
- [ ] Restart plan from today.

---

## 5.8 Flexible Reading Schedule

### Requirements

- [ ] User can choose fixed daily amount.
- [ ] User can choose flexible weekly goal.
- [ ] User can pause the plan.
- [ ] User can resume later.
- [ ] App recalculates progress when plan changes.

---

# 6. Memorization Features — ⬜ Not started

## 6.1 Daily Memorization Plan

### Requirements

- [ ] User selects surah/range for memorization.
- [ ] User sets daily memorization amount.
- [ ] App shows today's memorization target.
- [ ] App saves current memorization position.

---

## 6.2 Revision Schedule

### Requirements

- [ ] User can mark memorized ayahs.
- [ ] App schedules revision.
- [ ] Revision can be daily or custom.
- [ ] App shows revision due today.

---

## 6.3 Repeat Ayah / Range

### Requirements

- [ ] User can select one ayah or a range.
- [ ] User can repeat selected range.
- [ ] Audio can be added later, but the feature should be planned structurally.
- [ ] For now, repeat can support visual practice even without audio.

---

## 6.4 Select Start / End Ayah

### Requirements

- [ ] User can select:

  - [ ] Start surah
  - [ ] Start ayah
  - [ ] End surah
  - [ ] End ayah
- [ ] Used for memorization, revision, and reading plans.

---

## 6.5 Simple Memorization Test

A memorization test where words appear gradually.

### Requirements

- [ ] User selects an ayah/range.
- [ ] App hides parts of the ayah.
- [ ] Words appear gradually.
- [ ] User can tap to reveal next word.
- [ ] User can restart the test.
- [ ] User can mark result as:

  - [ ] Easy
  - [ ] Needs revision
  - [ ] Not memorized

---

## 6.6 Save Memorization Progress

### Requirements

- [ ] Save current memorization position locally.
- [ ] Save memorized ranges.
- [ ] Save revision status.
- [ ] Save last test result.
- [ ] Prepare structure for Google auth/cloud sync later.

---

# 7. Organization Features — ⬜ Not started

## 7.1 Bookmarks

### Requirements

- [ ] User can bookmark ayah/page.
- [ ] Bookmark stores:

  - [ ] Surah
  - [ ] Ayah
  - [ ] Page if available
  - [ ] Timestamp
  - [ ] Optional note
  - [ ] Optional category

---

## 7.2 Favorites

### Requirements

- [ ] User can favorite ayahs.
- [ ] Favorites are separate from bookmarks.
- [ ] Favorites are for ayahs the user wants to keep, not necessarily continue from.

---

## 7.3 Notes on Ayahs

### Requirements

- [ ] User can add private notes to ayahs.
- [ ] Notes stored locally.
- [ ] Notes can be edited/deleted.
- [ ] Notes should be accessible from ayah actions.

---

## 7.4 Bookmark Categories

### Requirements

Default categories:

- [ ] Reading
- [ ] Memorization
- [ ] Reflection
- [ ] Important
- [ ] Custom

User can create custom categories later.

---

## 7.5 Reading History

Reading history should not simply duplicate recently read pages. It should support insights and continuation.

### Requirements

Track:

- [ ] Opened surahs/pages
- [ ] Reading duration
- [ ] Completed sessions
- [ ] Interrupted sessions
- [ ] Daily progress
- [ ] Last read location

### Why It Matters

Reading history powers:

* Continue Reading
* Simple statistics
* Recently active sections
* Habit tracking
* Progress insights

---

## 7.6 Continue Reading Section

### Requirements

Show multiple auto-saved positions, such as:

- [ ] Last reading position
- [ ] Last memorization position
- [ ] Last revision position
- [ ] Last opened surah
- [ ] Last active plan position

### Example

Continue Reading

* Main reading: Al-Baqarah 120
* Memorization: Al-Mulk 5
* Revision: An-Naba 1–10

---

# 8. Ramadan Features — ⬜ Future Phase

These features should be planned but not necessarily developed in the first release.

## 8.1 Ramadan Khatmah Plan

- [ ] Create full Ramadan reading plan.
- [ ] One khatmah or multiple khatmah options.
- [ ] Daily amount calculation.
- [ ] Progress tracking.

## 8.2 Countdown to Ramadan

- [ ] Show remaining days.
- [ ] Encourage preparation before Ramadan.
- [ ] Connect with pre-Ramadan habit plan.

## 8.3 Pre-Ramadan Preparation Plan

- [ ] Daily Quran habit before Ramadan.
- [ ] Gradual increase.
- [ ] Simple fixed daily program.

## 8.4 30-Day Challenge

- [ ] Daily reading challenge.
- [ ] Completion badges.
- [ ] Shareable progress later.

## 8.5 Group Khatmah

- [ ] Users join a group khatmah.
- [ ] Assign parts.
- [ ] Track completion.
- [ ] Requires backend/auth, so should be future only.

## 8.6 Ramadan-Specific Reminders

- [ ] Suhoor reminder.
- [ ] After Fajr reading reminder.
- [ ] Before Maghrib reminder.
- [ ] Taraweeh-related reading reminder.

---

# 9. User Experience Features — 🔄 Partial

## 9.1 Focus Reading Mode — ⬜ Not started

Focus Reading Mode means a clean Quran reading screen with minimal UI.

### Requirements

- [ ] Hide bottom navigation.
- [ ] Hide extra buttons.
- [ ] Show Quran text only.
- [ ] Tap screen to reveal controls.
- [ ] Keep bookmark/ayah actions accessible but not visually noisy.
- [ ] Useful for long reading sessions.

---

## 9.2 Distraction-Free Mode

Merge with Focus Reading Mode.

Do not build as a separate feature.

---

## 9.3 Daily Achievement Screen — ⬜ Not started

### Requirements

After completing daily wird, show a simple achievement screen.

### Content

- [ ] Today's target completed
- [ ] Current streak
- [ ] Khatmah progress
- [ ] Gentle encouragement

### Example

You completed today's wird.
Current streak: 5 days
Khatmah progress: 18%

---

## 9.4 Simple Statistics Page — ⬜ Not started

### Requirements

Show simple stats only.

### Metrics

- [ ] Current streak
- [ ] Total reading days
- [ ] Pages read this week
- [ ] Ayahs read this week
- [ ] Current khatmah progress
- [ ] Memorization progress
- [ ] Most-read surahs

Avoid complex analytics.

---

## 9.5 Calm Color Themes — 🔄 Partial

### Requirements

Provide simple reading themes:

- [x] Light
- [x] Dark
- [ ] Sepia
- [ ] Green calm
- [ ] Blue calm
- [x] Save selected theme locally.

---

## 9.6 Reading Goal Dashboard — ⬜ Not started

### Requirements

Home screen should show:

- [ ] Continue Reading
- [ ] Today's Wird
- [ ] Current streak
- [ ] Khatmah progress
- [ ] Memorization target
- [ ] Quick access to bookmarks

---

# 10. Later Advanced Features — ⬜ Not started

These should be planned structurally but not built first unless needed.

## 10.1 Sync Across Devices

Requires user account.

Sync:

- [ ] Bookmarks
- [ ] Notes
- [ ] Reading progress
- [ ] Memorization progress
- [ ] Preferences

---

## 10.2 Optional User Account — 🔄 Partial

Possible providers:

- [~] Firebase infrastructure initialized *(FCM, firebase_core done; no auth yet)*
- [ ] Google auth
- [ ] Apple auth
- [ ] Email auth later

Account must remain optional.

---

## 10.3 Backup Bookmarks and Notes

- [ ] Can be part of sync feature.

---

## 10.4 Share Ayah as Image

### Requirements

- [ ] Select ayah.
- [ ] Generate clean share card.
- [ ] Support Arabic text.
- [ ] Add app name/logo lightly.
- [ ] Allow saving/sharing image.

---

## 10.5 Daily Wird Widget

- [ ] Future mobile widget showing today's wird, progress, and continue button.

---

## 10.6 Mushaf Page Mode

### Requirements

- [ ] Display Quran by Mushaf page.
- [ ] Support page navigation.
- [ ] Save last page.
- [ ] Highlight current ayah if possible.
- [ ] This can be a later phase if current text-based reading is already stable.

---

## 10.7 Short Tafsir Support

Only plan for it now.

Possible future:

- [ ] Short tafsir per ayah.
- [ ] Trusted source.
- [ ] Offline tafsir data.
- [ ] Keep it optional and hidden by default.

---

# 11. Data Model - Local Storage

Suggested local entities:

## UserPreferences — 🔄 Partial

- [ ] id
- [x] themeMode
- [x] fontSize
- [ ] readingMode
- [ ] lastOpenedScreen
- [ ] reminderEnabled
- [ ] reminderTime
- [ ] createdAt
- [ ] updatedAt

---

## ReadingPosition — 🔄 Partial

- [x] type: main_reading *(single type only)*
- [ ] type: memorization | revision | plan
- [x] surahNumber *(inferred from saved ayah id)*
- [x] ayahNumber
- [ ] pageNumber
- [x] scrollOffset *(anchor offset saved)*
- [x] juzNumber *(inferred)*
- [x] updatedAt

---

## ReadingSession — ⬜ Not started

- [ ] id
- [ ] startedAt
- [ ] endedAt
- [ ] startSurah / startAyah
- [ ] endSurah / endAyah
- [ ] pagesRead
- [ ] ayahsRead
- [ ] durationSeconds
- [ ] completedDailyTarget
- [ ] createdAt

---

## DailyWirdPlan — ⬜ Not started

- [ ] id
- [ ] targetType: pages | ayahs | minutes | khatmah
- [ ] targetValue
- [ ] startDate / endDate
- [ ] isActive
- [ ] recoveryMode
- [ ] createdAt / updatedAt

---

## DailyWirdProgress — ⬜ Not started

- [ ] id
- [ ] date
- [ ] planId
- [ ] targetValue / completedValue
- [ ] isCompleted / completedAt
- [ ] createdAt

---

## Bookmark — ⬜ Not started

- [ ] id
- [ ] surahNumber / ayahNumber / pageNumber
- [ ] categoryId
- [ ] note
- [ ] createdAt / updatedAt

---

## Favorite — ⬜ Not started

- [ ] id
- [ ] surahNumber / ayahNumber
- [ ] createdAt

---

## AyahNote — ⬜ Not started

- [ ] id
- [ ] surahNumber / ayahNumber
- [ ] content
- [ ] createdAt / updatedAt

---

## BookmarkCategory — ⬜ Not started

- [ ] id
- [ ] name / color
- [ ] createdAt / updatedAt

---

## MemorizationPlan — ⬜ Not started

- [ ] id
- [ ] startSurah / startAyah / endSurah / endAyah
- [ ] dailyAmount
- [ ] isActive
- [ ] createdAt / updatedAt

---

## MemorizationProgress — ⬜ Not started

- [ ] id
- [ ] planId
- [ ] surahNumber / ayahNumber
- [ ] status: not_started | learning | memorized | needs_revision
- [ ] lastReviewedAt / nextReviewAt
- [ ] createdAt / updatedAt

---

## MemorizationTestResult — ⬜ Not started

- [ ] id
- [ ] surahNumber / startAyah / endAyah
- [ ] result: easy | needs_revision | not_memorized
- [ ] createdAt

---

# 12. Main Screens

## 12.1 Home Screen — ⬜ Not started

Sections:

- [ ] Continue Reading
- [ ] Today's Wird
- [ ] Current Streak
- [ ] Khatmah Progress
- [ ] Memorization Target
- [ ] Bookmarks Shortcut

---

## 12.2 Quran Reading Screen — 🔄 Partial

Features:

- [x] Quran text
- [ ] Ayah actions panel
- [ ] Bookmark from reading screen
- [ ] Favorite from reading screen
- [ ] Note from reading screen
- [x] Font size control
- [x] Theme control
- [ ] Focus mode
- [x] Surah/juz/page navigation
- [x] Auto-save reading position

---

## 12.3 Surah List Screen — ✅ Done

Features:

- [x] Search surah
- [x] Show surah name
- [x] Show ayah count
- [~] Continue from surah if previously opened *(navigates to first ayah, not last-read position within surah)*

---

## 12.4 Juz List Screen — ✅ Done

Features:

- [x] Show juz list
- [x] Open juz
- [ ] Continue from last ayah inside juz *(future: requires per-juz saved position)*

---

## 12.5 Daily Wird Screen — ⬜ Not started

Features:

- [ ] Create/edit daily target
- [ ] Show today's progress
- [ ] Mark as complete
- [ ] Show recovery options
- [ ] Show streak

---

## 12.6 Khatmah Plan Screen — ⬜ Not started

Features:

- [ ] Select target date
- [ ] Calculate daily amount
- [ ] Show progress
- [ ] Adjust missed days
- [ ] Continue today's assigned reading

---

## 12.7 Memorization Screen — ⬜ Not started

Features:

- [ ] Create memorization plan
- [ ] Select range
- [ ] View today's memorization
- [ ] View revision due
- [ ] Start gradual-word test

---

## 12.8 Bookmarks Screen — ⬜ Not started

Features:

- [ ] List bookmarks
- [ ] Filter by category
- [ ] Search bookmarks
- [ ] Open bookmark
- [ ] Edit/delete bookmark

---

## 12.9 Notes Screen — ⬜ Not started

Features:

- [ ] List ayah notes
- [ ] Open ayah from note
- [ ] Edit/delete note

---

## 12.10 Statistics Screen — ⬜ Not started

Features:

- [ ] Current streak
- [ ] Reading days
- [ ] Weekly reading progress
- [ ] Khatmah progress
- [ ] Memorization progress

---

## 12.11 Settings Screen — ⬜ Not started

Features:

- [x] Theme mode
- [ ] Font size
- [ ] Reminder time
- [ ] Reading preferences
- [ ] Data backup later
- [x] About Quran source *(in info dialog)*

---

# 13. Notifications — 🔄 Infrastructure only

## 13.1 Daily Wird Reminder

- [~] FCM infrastructure initialized *(firebase_messaging set up; no scheduled local notification yet)*
- [ ] Daily wird reminder configured and scheduled

Title: Continue your daily wird
Body: A small reading today keeps your Quran habit alive.

## 13.2 Pre-Ramadan Habit Reminder

- [ ] Scheduled and configured

Title: Build a habit before Ramadan
Body: Start today with a steady Quran program, even if it is only a few ayahs.

## 13.3 Missed Day Gentle Reminder

- [ ] Scheduled and configured

Title: Continue without pressure
Body: You can continue today. Your plan can adjust softly.

---

# 14. Technical Notes

## Local Storage

Use a reliable local database/storage layer suitable for the current app stack.

Suggested options:

- [x] SQLite *(used for Quran text; not yet used for user data)*
- [ ] Hive or Isar *(for user data: bookmarks, notes, wird progress, memorization)*
- [x] SharedPreferences *(for simple preferences: font size)*

Use database storage for:

- [ ] Bookmarks
- [ ] Notes
- [ ] Reading history
- [ ] Wird progress
- [ ] Memorization progress

Use simple preferences for:

- [x] Font size
- [x] Theme
- [ ] Reminder settings

---

## Offline Support

- [x] The Quran text is available offline.
- [x] The app does not require internet for core reading.

---

## Future Sync Preparation

Even if sync is not implemented now, local entities should use stable IDs and timestamps.

- [ ] createdAt / updatedAt on all entities
- [ ] deletedAt if soft delete is needed later
- [ ] syncStatus if cloud sync is added

---

# 15. Development Phases

## Phase 1 - Stability and Reading Core — ✅ Done

- [x] Fix reading-position management
- [x] Resume exact ayah/page
- [x] Improve surah/juz/page switching
- [x] Improve page loading performance
- [x] Add font size controller
- [x] Improve dark mode
- [x] Save reading preferences/session

---

## Phase 2 - Daily Wird and Habit System — ⬜ Not started

- [ ] Daily reading program
- [ ] Daily wird target
- [ ] Progress tracking
- [ ] Daily reminder
- [ ] Reading streak
- [ ] Missed-day recovery
- [ ] Flexible schedule

---

## Phase 3 - Organization — ⬜ Not started

- [ ] Bookmarks
- [ ] Favorites
- [ ] Notes on ayahs
- [ ] Bookmark categories
- [ ] Reading history
- [ ] Continue Reading section with multiple auto-saved positions

---

## Phase 4 - Memorization — ⬜ Not started

- [ ] Daily memorization plan
- [ ] Revision schedule
- [ ] Repeat ayah/range
- [ ] Select start/end ayah
- [ ] Gradual-word memorization test
- [ ] Save memorization progress

---

## Phase 5 - Ramadan Features — ⬜ Not started

- [ ] Ramadan khatmah plan
- [ ] Countdown to Ramadan
- [ ] Pre-Ramadan preparation plan
- [ ] 30-day challenge
- [ ] Ramadan reminders

Group khatmah should remain future because it requires account/backend.

---

## Phase 6 - Advanced Features — ⬜ Not started

- [~] Optional account *(Firebase core initialized; no auth yet)*
- [ ] Sync across devices
- [ ] Backup bookmarks/notes
- [ ] Share ayah as image
- [ ] Daily wird widget
- [ ] Mushaf page mode
- [ ] Short tafsir support

---

# 16. MVP Recommendation

The first release should focus on:

- [x] Reading-position/session fixes
- [ ] Continue Reading
- [ ] Daily wird target
- [ ] Daily reminder
- [ ] Progress tracking
- [ ] Reading streak
- [ ] Bookmarks
- [ ] Favorites
- [ ] Notes
- [ ] Basic memorization progress

Do not start with account, sync, group khatmah, tafsir, or complex analytics.

---

# 17. Important UX Rules

* Do not overload the home screen.
* Do not make missed days feel negative.
* Keep the reading screen clean.
* Make daily progress visible but calm.
* Always allow the user to continue without resetting their plan.
* Keep account/login optional.
* Keep core Quran reading fully offline.
* Avoid turning the app into a heavy dashboard.

---

# 18. App Store / Review Positioning

The app should be positioned as an interactive Quran reading and habit-building app, not only a digital book.

Emphasize:

* Daily reading plans
* Progress tracking
* Bookmarks
* Notes
* Memorization tools
* Reminders
* Reading history
* Personalized reading preferences
* Khatmah planning

This helps show that the app has software functionality beyond static text.

---

# 19. Final Product Description

القرآن الكريم يسر is a simple Quran companion that helps users read consistently, continue from where they stopped, manage their daily wird, track progress, memorize and revise ayahs, and prepare for Ramadan through a stable daily program.

The app should remain calm, fast, offline-first, and focused on the Quran.
