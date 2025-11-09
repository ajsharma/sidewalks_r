# PRD: Power User Features for AI Activity System

**Version:** 1.0
**Status:** Draft - Phase 2
**Last Updated:** 2025-11-08
**Owner:** Product Team
**Related PRD:** `prd_ai_activity_suggestions.md` (Phase 1)

---

## 1. Overview

### Problem Statement
After using the basic AI activity suggestion feature, power users will want:
- Faster workflows through shortcuts and automation
- Personalization based on their unique patterns
- Bulk operations for managing multiple activities
- More control over AI behavior

These advanced capabilities should not complicate the experience for casual users, but should be discoverable and powerful for those who need them.

### Goals
Empower power users with:
1. **Natural language shortcuts** for common operations
2. **Pattern learning** from historical behavior
3. **Bulk operations** for efficiency
4. **Advanced customization** of AI suggestions
5. **Keyboard-driven workflows** for speed

### Success Metrics
- **Power User Adoption**: % of users who use 3+ power features
- **Keyboard Shortcut Usage**: % of activities created via shortcuts
- **Bulk Operation Usage**: Avg activities created per bulk operation
- **Learning Accuracy**: % improvement in AI suggestions over time (per user)
- **Time Savings**: Reduction in time-to-create for power users vs casual users

---

## 2. User Stories

### As a Power User

**Natural Language Shortcuts:**
- I want to type shortcuts like ⌘K to quickly add activities from anywhere
- I want to use patterns like "coffee with Sarah every Tuesday 9am" to create recurring events instantly
- I want templates for common activities ("Add gym session" → auto-fills typical details)

**AI Learning & Personalization:**
- I want the AI to learn that I prefer morning hikes (not afternoon)
- I want the AI to remember my favorite venues and suggest them
- I want to see how AI is learning my patterns ("You usually schedule coffee on weekdays")
- I want to correct AI assumptions and have it remember my corrections

**Bulk Operations:**
- I want to paste a list of activities and have them all processed at once
- I want to import events from a calendar file (ICS)
- I want to bulk-edit AI suggestions before accepting them

**Advanced Customization:**
- I want to set default scheduling preferences (weekends only, mornings only, etc.)
- I want to customize which playlists certain activity types auto-categorize into
- I want to disable AI for specific fields I always want to control manually

**Keyboard Workflows:**
- I want keyboard shortcuts for "Accept suggestion" (Enter) and "Customize" (Tab)
- I want to navigate between suggestion fields with arrow keys
- I want vim-style keybindings as an option (j/k for navigation, dd to dismiss)

---

## 3. Functional Requirements

### 3.1 Quick Add Shortcuts

**FR-1.1: Global Keyboard Shortcut**
- Default: ⌘K (Mac) / Ctrl+K (Windows/Linux)
- Opens AI input overlay from any page
- Focus immediately in input field
- ESC to close

**FR-1.2: Command Palette**
- Type "/" to see available commands
- Commands:
  - `/add` - Add new activity
  - `/bulk` - Bulk add activities
  - `/template` - Use saved template
  - `/import` - Import from file

**FR-1.3: Smart Patterns**
```
Input: "gym MWF 6am"
→ Creates: "Gym Session" every Monday/Wednesday/Friday at 6:00 AM

Input: "team lunch every other Friday"
→ Creates: "Team Lunch" bi-weekly on Fridays

Input: "coffee with @Sarah tomorrow"
→ Creates: "Coffee with Sarah" for tomorrow, suggests inviting Sarah (if user exists)
```

### 3.2 AI Pattern Learning

**FR-2.1: Implicit Learning**
- Track user edits to AI suggestions
- Identify patterns:
  - User always changes "afternoon" → "morning" for hikes
  - User always sets "max_frequency: 7" for social activities
  - User prefers specific playlists for certain tags

**FR-2.2: Explicit Preferences**
- User settings page: "AI Preferences"
- Configure:
  - Default schedule type (flexible, scheduled, deadline)
  - Preferred time of day per activity type
  - Preferred days of week (weekdays only, weekends only, etc.)
  - Auto-categorization rules

**FR-2.3: Learning Indicators**
```
┌─────────────────────────────────────────┐
│ 🧠 AI is learning your preferences      │
│                                         │
│ ✓ You prefer morning hikes (5/5 times) │
│ ✓ Coffee always on weekdays (8/8)      │
│ ⚡ Applied to this suggestion           │
└─────────────────────────────────────────┘
```

**FR-2.4: Pattern Correction**
```
AI suggested: "Afternoon hike"

User corrects to: "Morning hike"

System asks: "Always suggest morning for hikes?"
[Yes, remember this] [No, just this time]
```

### 3.3 Bulk Activity Creation

**FR-3.1: Multi-Line Input**
```
Paste or type multiple activities:

- Go apple picking in October
- Visit farmers market this Saturday
- Try new Thai restaurant on Main St
- Book dentist appointment before end of month

[Process All (4 activities)]
```

**FR-3.2: Bulk Review UI**
```
┌─────────────────────────────────────────┐
│ 4 activities suggested                  │
│                                         │
│ ☑ Apple Picking - Oct, Weekends        │
│ ☑ Farmers Market - Sat 9am             │
│ ☐ Thai Restaurant - Anytime (⚠️ low confidence) │
│ ☑ Dentist Appointment - Before Dec 31  │
│                                         │
│ [Select All] [Add 3 Selected] [Review] │
└─────────────────────────────────────────┘
```

**FR-3.3: ICS/CSV Import**
- Upload `.ics` calendar file
- Parse events
- Convert to activities with AI enrichment
- Bulk review interface

### 3.4 Activity Templates

**FR-4.1: Template Creation**
```
Save common activities as templates:

Template Name: "Weekly Team Standup"
├─ Schedule: Every Monday 10:00 AM
├─ Duration: 30 minutes
├─ Playlist: Work Meetings
├─ Tags: recurring, work
└─ Max Frequency: 7 days
```

**FR-4.2: Template Usage**
```
Quick add: "Add standup"
→ AI recognizes template keyword
→ Suggests using "Weekly Team Standup" template
→ One-click to create
```

**FR-4.3: Template Marketplace (Phase 3)**
- Community-shared templates
- Popular templates: "Morning routine", "Date night", "Weekend hike"
- Import templates from other users

### 3.5 Advanced AI Controls

**FR-5.1: AI Preference Profiles**
```
┌─────────────────────────────────────────┐
│ AI Behavior Settings                    │
│                                         │
│ Scheduling Preferences:                 │
│ □ Only suggest weekdays for work tasks │
│ ☑ Prefer mornings for outdoor activities│
│ □ Avoid Friday/Saturday for routine tasks│
│                                         │
│ Categorization:                         │
│ ☑ Auto-assign to playlists             │
│ □ Always ask before categorizing        │
│                                         │
│ Learning:                               │
│ ☑ Learn from my edits                  │
│ ☑ Show what AI learned                 │
│ □ Reset learning data                  │
└─────────────────────────────────────────┘
```

**FR-5.2: Field Locking**
```
Lock fields AI should never modify:
☑ Playlist (I always choose manually)
☐ Time of day
☑ Max frequency
```

**FR-5.3: Confidence Threshold**
```
Only show suggestions when confidence > [__75__]%

Below threshold:
● Show warning but allow review
○ Auto-fallback to manual input
```

### 3.6 Keyboard Navigation

**FR-6.1: Global Shortcuts**
```
⌘K / Ctrl+K    - Open quick add
⌘Enter         - Accept suggestion
⌘E             - Edit/customize suggestion
Escape         - Dismiss/close
⌘/             - Show keyboard shortcuts help
```

**FR-6.2: Review UI Navigation**
```
Tab / Shift+Tab - Navigate fields
Space          - Toggle checkboxes
Enter          - Confirm current field
Arrow keys     - Navigate in dropdowns
j/k (vim mode) - Next/previous field
```

**FR-6.3: Bulk Operations**
```
⌘A             - Select all suggestions
⌘Shift+Enter  - Bulk accept selected
⌘D             - Dismiss selected
```

---

## 4. Technical Architecture

### AI Learning System

**Learning Model Structure:**
```ruby
# app/models/user_ai_preference.rb

class UserAiPreference < ApplicationRecord
  belongs_to :user

  # Learned patterns (JSONB)
  # {
  #   "time_preferences": {
  #     "hiking": "morning",      # 95% confidence
  #     "coffee": "morning",      # 80% confidence
  #     "dinner": "evening"       # 100% confidence
  #   },
  #   "day_preferences": {
  #     "social": [6, 7],         # weekends
  #     "work": [1, 2, 3, 4, 5]   # weekdays
  #   },
  #   "frequency_patterns": {
  #     "gym": 7,                 # weekly
  #     "museum": 90              # quarterly
  #   },
  #   "playlist_rules": {
  #     "outdoor": "Adventures",
  #     "food": "Dining Out"
  #   }
  # }

  store :learned_patterns, coder: JSON
  store :explicit_preferences, coder: JSON
  store :field_locks, coder: JSON
end
```

**Learning Algorithm:**
```ruby
# app/services/ai_pattern_learner.rb

class AiPatternLearner
  def initialize(user)
    @user = user
    @preferences = user.ai_preference || user.create_ai_preference
  end

  def learn_from_edit(suggestion, final_activity)
    # Compare AI suggestion vs user's final choices
    diff = calculate_diff(suggestion.suggested_data, activity_attributes(final_activity))

    # Update learned patterns
    diff.each do |field, change|
      update_pattern(field, change)
    end

    @preferences.save!
  end

  private

  def calculate_diff(suggested, final)
    diff = {}

    # Time of day changes
    if suggested['suggested_time_of_day'] != final['suggested_time_of_day']
      diff[:time_of_day] = {
        context: infer_context(final),  # e.g., "hiking"
        from: suggested['suggested_time_of_day'],
        to: final['suggested_time_of_day']
      }
    end

    # Similar for other fields...

    diff
  end

  def update_pattern(field, change)
    case field
    when :time_of_day
      context = change[:context]
      patterns = @preferences.learned_patterns['time_preferences'] ||= {}

      # Increment confidence for this pattern
      patterns[context] ||= { value: change[:to], count: 0 }
      patterns[context][:count] += 1

      # If 3+ occurrences, lock it in
      if patterns[context][:count] >= 3
        patterns[context][:value] = change[:to]
        patterns[context][:confidence] = calculate_confidence(patterns[context][:count])
      end
    end
  end
end
```

### Template System

**Database Schema:**
```ruby
# Migration: create_activity_templates

create_table :activity_templates do |t|
  t.references :user, foreign_key: true, null: false
  t.string :name, null: false
  t.text :description
  t.string :trigger_keywords, array: true, default: []

  # Template data (JSON)
  t.jsonb :template_data, null: false, default: {}

  # Usage stats
  t.integer :usage_count, default: 0
  t.datetime :last_used_at

  # Sharing (Phase 3)
  t.boolean :public, default: false
  t.integer :likes_count, default: 0

  t.timestamps
end

add_index :activity_templates, [:user_id, :name], unique: true
add_index :activity_templates, :trigger_keywords, using: :gin
add_index :activity_templates, :public
```

### Bulk Processing Job

```ruby
# app/jobs/bulk_activity_processor_job.rb

class BulkActivityProcessorJob < ApplicationJob
  queue_as :ai_processing

  def perform(user_id, activities_text, request_id)
    user = User.find(user_id)

    # Parse multi-line input
    lines = activities_text.split("\n").reject(&:blank?)

    suggestions = []

    lines.each_with_index do |line, index|
      # Process each line as separate activity
      service = AiActivityService.new(user: user, input: line.strip)

      begin
        suggestion = service.generate_suggestion
        suggestions << suggestion
      rescue => e
        # Continue processing others, track error
        suggestions << { error: true, line: line, message: e.message }
      end

      # Progress update every 5 items
      if (index + 1) % 5 == 0
        broadcast_progress(user, index + 1, lines.size, request_id)
      end
    end

    # Broadcast all suggestions at once
    broadcast_bulk_result(user, suggestions, request_id)
  end
end
```

---

## 5. User Interface Enhancements

### Command Palette UI

```
Press ⌘K anywhere:

┌─────────────────────────────────────────────┐
│ > type to search...                         │
├─────────────────────────────────────────────┤
│ 🎯 Quick Actions                            │
│   ⚡ Add activity                           │
│   📋 Bulk add activities                    │
│   📁 Use template                           │
│   📥 Import from file                       │
│                                             │
│ 📝 Recent Templates                         │
│   Weekly Team Standup                       │
│   Morning Workout                           │
│   Date Night                                │
│                                             │
│ ⚙️  Settings                                │
│   AI Preferences                            │
│   Keyboard Shortcuts                        │
└─────────────────────────────────────────────┘
```

### Learning Insights Dashboard

```
┌─────────────────────────────────────────────┐
│ 🧠 Your AI Learning Progress                │
├─────────────────────────────────────────────┤
│ Accuracy: 89% → 94% (last 30 days)  ⬆ +5%  │
│                                             │
│ What AI Learned About You:                 │
│                                             │
│ ✓ Hiking activities                        │
│   → Always morning (10/10 times)           │
│   → Weekends only (9/10 times)             │
│   → "Adventures" playlist (10/10)          │
│   [Reset this pattern]                     │
│                                             │
│ ✓ Coffee meetings                          │
│   → Weekday mornings (15/16 times)         │
│   → 30 min duration (12/15 times)          │
│   → "Social" playlist (14/16)              │
│   [Reset this pattern]                     │
│                                             │
│ 📊 Activity Stats                           │
│   89 activities via AI (78% of total)      │
│   67% accepted without edits               │
│   Most common edit: Time of day            │
└─────────────────────────────────────────────┘
```

---

## 6. Success Criteria

### MVP (Phase 2A - 2 weeks)
- ✅ Global ⌘K shortcut
- ✅ Keyboard navigation in review UI
- ✅ Basic pattern learning (time of day, day of week)
- ✅ Learning insights display
- ✅ Pattern correction flow

### Phase 2B (2 weeks)
- ✅ Bulk multi-line input
- ✅ Activity templates (create, use, manage)
- ✅ Advanced AI preferences page
- ✅ Field locking

### Phase 2C (Future)
- ⏸ ICS import
- ⏸ Template marketplace
- ⏸ Vim keybindings mode
- ⏸ Command palette autocomplete

---

## 7. Metrics & Analytics

Track these power user engagement metrics:

```ruby
# app/models/power_user_metric.rb

class PowerUserMetric
  THRESHOLDS = {
    casual: 0,          # Uses AI occasionally
    regular: 3,         # Uses 3+ AI features
    power: 5,           # Uses 5+ features including keyboard shortcuts
    expert: 8           # Uses templates, bulk, custom preferences
  }

  def self.classify_user(user)
    features_used = count_features_used(user)

    case features_used
    when 0..2 then :casual
    when 3..4 then :regular
    when 5..7 then :power
    else :expert
    end
  end

  def self.count_features_used(user)
    count = 0

    # Check feature usage
    count += 1 if user.used_keyboard_shortcuts?
    count += 1 if user.used_bulk_add?
    count += 1 if user.has_templates?
    count += 1 if user.customized_ai_preferences?
    count += 1 if user.ai_accuracy_improved?
    count += 1 if user.uses_field_locking?
    # ... etc

    count
  end
end
```

---

## 8. Out of Scope (Phase 3+)

- Natural language queries ("What should I do this weekend?")
- Conversational AI refinement ("Make it earlier" → adjusts time)
- Voice input via speech-to-text
- API for third-party integrations
- Browser extension for direct URL capture
- Mobile app-specific power features (gestures, widgets)

---

*End of Power User Features PRD*
