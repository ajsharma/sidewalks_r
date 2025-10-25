# Gem Update Improvements Plan

**Date:** 2025-10-25
**Update:** Rails 8.0.2.1 → 8.1.0 and other dependency updates

## Bundle Update Summary

### Major Updates
- **Rails**: 8.0.2.1 → 8.1.0 (minor version bump)
- **Puma**: 7.0.4 → 7.1.0
- **RuboCop**: 1.79.1 → 1.81.6
- **Kamal**: 2.7.0 → 2.8.1
- **Selenium WebDriver**: 4.36.0 → 4.38.0

### Other Notable Updates
- activesupport, actionpack, actionview, actionmailer, activejob, activerecord, railties, actioncable, activestorage, actionmailbox, actiontext all updated to 8.1.0
- solid_queue: 1.2.1 → 1.2.2
- solid_cache: 1.0.7 → 1.0.8
- solid_cable: 3.0.11 → 3.0.12
- rubocop-rails: 2.32.0 → 2.33.4
- rubocop-performance: 1.25.0 → 1.26.1
- strong_migrations: 2.5.0 → 2.5.1
- bullet: 8.0.8 → 8.1.0

## Current Test Status

✅ **All tests passing**: 265 runs, 730 assertions, 0 failures, 0 errors, 3 skips
✅ **Code coverage**: 87.67% (1237 / 1411 lines)
✅ **Security**: No Brakeman warnings
✅ **Gem vulnerabilities**: None found
✅ **Code quality**: No Reek warnings
✅ **Rails best practices**: No warnings
✅ **RuboCop**: No offenses

## Issues to Address

### 1. Deprecation Warnings (High Priority)

#### 1.1 ActiveSupport::Configurable Deprecation
**Impact:** Will break in Rails 8.2
**Location:** `config/application.rb:7`
**Warning:**
```
DEPRECATION WARNING: ActiveSupport::Configurable is deprecated without replacement,
and will be removed in Rails 8.2.
You can emulate the previous behavior with `class_attribute`.
```

**Action Required:**
- Investigate where `ActiveSupport::Configurable` is being used
- Replace with `class_attribute` as recommended
- Test thoroughly to ensure behavior is preserved

#### 1.2 Routes Deprecation Warnings
**Impact:** Will break in Rails 8.2
**Location:** `config/routes.rb:8`
**Warnings:**
```
DEPRECATION WARNING: resource received a hash argument only. Please use a keyword instead.
DEPRECATION WARNING: resource received a hash argument path. Please use a keyword instead.
DEPRECATION WARNING: resource received a hash argument path_names. Please use a keyword instead.
DEPRECATION WARNING: resource received a hash argument controller. Please use a keyword instead.
```

**Action Required:**
- Convert hash arguments to keyword arguments in routes.rb
- Change from: `resource :foo, { only: :show, path: 'bar' }`
- Change to: `resource :foo, only: :show, path: 'bar'`

### 2. SimpleCov Coverage Warnings (Medium Priority)

**Issue:** Coverage data exceeds number of lines in 20 view files
**Affected Files:**
- `app/views/activities/_form.html.erb` (133 > 131)
- `app/views/activities/edit.html.erb` (20 > 17)
- `app/views/activities/index.html.erb` (98 > 95)
- `app/views/activities/new.html.erb` (13 > 10)
- `app/views/activities/show.html.erb` (139 > 136)
- `app/views/activity_scheduling/preview.html.erb` (173 > 171)
- `app/views/activity_scheduling/show.html.erb` (251 > 249)
- `app/views/devise/passwords/new.html.erb` (39 > 36)
- `app/views/devise/registrations/edit.html.erb` (106 > 103)
- `app/views/devise/registrations/new.html.erb` (65 > 62)
- `app/views/devise/sessions/new.html.erb` (53 > 50)
- `app/views/devise/shared/_error_messages.html.erb` (17 > 15)
- `app/views/devise/shared/_links.html.erb` (39 > 36)
- `app/views/home/index.html.erb` (7 > 4)
- `app/views/layouts/application.html.erb` (162 > 159)
- `app/views/playlists/_form.html.erb` (36 > 34)
- `app/views/playlists/edit.html.erb` (20 > 17)
- `app/views/playlists/index.html.erb` (72 > 69)
- `app/views/playlists/new.html.erb` (13 > 10)
- `app/views/playlists/show.html.erb` (120 > 117)

**Action Required:**
- This is likely a SimpleCov bug or ERB line counting issue
- Update SimpleCov configuration to handle ERB files better
- Consider filtering these warnings if they're harmless

### 3. Documentation Coverage (Low Priority)

**Current Status:** 74.29% documented
**Gaps:**
- 35 undocumented methods out of 101 total methods
- 1 undocumented constant out of 6 total constants

**Action Required:**
- Add YARD documentation to undocumented methods
- Document the undocumented constant
- Aim for 90%+ documentation coverage

## Implementation Plan

### Phase 1: Critical Deprecations (Before Rails 8.2)
1. Fix ActiveSupport::Configurable deprecation
2. Fix routes.rb hash argument deprecations
3. Run full test suite to verify fixes
4. Deploy and monitor

### Phase 2: Coverage Warnings
1. Research SimpleCov + ERB line counting issues
2. Update SimpleCov configuration or filter warnings
3. Document findings in this file

### Phase 3: Documentation
1. Run YARD with verbose output to identify undocumented methods
2. Add documentation to methods and constants
3. Verify documentation coverage improves

## Success Criteria

- [ ] Zero deprecation warnings when running `bin/go`
- [ ] All tests still passing
- [ ] No new security vulnerabilities
- [ ] No new code quality issues
- [ ] Documentation coverage above 90%
- [ ] SimpleCov warnings resolved or documented as acceptable

## Notes

- All current tests are passing after the gem updates
- No breaking changes detected in the test suite
- Security posture remains strong with no vulnerabilities
- Code quality metrics remain excellent
