# AzeriteUI_Classic Change Log
All notable changes to this project will be documented in this file. Be aware that the [Unreleased] features might not all be part of the next update, nor will all of them even be available in the latest development version. Instead they are provided to give the users somewhat of a preview of what's to come. 

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.0.35-RC] 2019-08-31
### Fixed
- Locked the main chat in a manner not affecting its DropDown, thus preventing taint from spreading to the Compact group frames. 

## [1.0.34-RC] 2019-08-31
### Fixed
- Fixed a typo causing the UI to bug out when your pet was just content, not happy. I thought this was a feature? :)

### Changed
- Made the aura filters even less filterish. We need actual lists here, since we can't check any real meta info of units not in our group. Will get myself up a few levels, then take a day to get this right!
- Removed the 3 limit buff cap on the target frame aura element. When you're a healer, you probably need to see more than just 3 happy ones. 
- Added an extra row of auras to the target frame, just to make sure we don't miss stuff while the filters are unfilterish. 

## [1.0.33-RC] 2019-08-31
### Added
- Added an experimental feature to show spell rank on actionbuttons when more than one instance of the spell currently exists on your buttons. 

### Changed
- Made the difference between usable and not usable spells more distinct. 

## [1.0.32-RC] 2019-08-30
### Fixed
- Fixed a typo causing an error when summoning pets. 

## [1.0.31-RC] 2019-08-30
### Changed
- Fixed some aura border coloring inconsistencies, as well as applied debuff type coloring to most auras that have a type. 

## [1.0.30-RC] 2019-08-30
### Fixed
- There should no longer be any misalignment when mousing over the world map to select zones.

## [1.0.29-RC] 2019-08-30
### Added
- Added a fix for players that suffered from AzeriteUI not loading because they mistakingly has TukUI or ElvUI installed. AzeriteUI should now load anyway, despite that horrible addon list. 

## [1.0.28-RC] 2019-08-30
### Fixed
- Player PvP icon should now properly be hidden while engaged in combat, to make room for the combat indicator. 

## [1.0.27-RC] 2019-08-30
### Added
- Added Pet Happiness as an experimental message to the bottom of the screen. 

## [1.0.26-RC] 2019-08-29
### Added
- Added a player PvP icon. It is placed where the combat indicator is, and thus hidden while in combat. 

### Changed
- Made the world map smaller, and stopped it from blocking out the world. We are aware that the overlay to click on zones is slightly misaligned, working on that. 
- Changed the aura filters to be pretty all inclusive. Will tune it for classic later on. 

### Fixed
- Fixed the display of Druid cat form combo points. It should now appear. If you're wondering why the points disappear everytime you change target, that's not a bug. That's a classic feature. 
- Fixed a bug when opening the talent window. 
- Fixed a lot of small issues and bugs related to auras and castbars. 

### Removed
- Disabled all castbars on frames other than the player and the pet. We will add a limited tracking system for hostile player casts by tracking combat log events later on. 

## [1.0.16-RC] 2019-08-12
### Changed
- The quest tracker now looks far more awesome. 
- The texture for active or checked abilities on the action buttons will now be hidden if the red auto-attack flash is currently flashing, making everything far easier to see and relate to. 
- Made the tooltip for auto-attack much more interesting, as it now shows your main- and off hand damage, attack speed and damage per second. Just like the weapon tooltips in principle, but with actual damage modifiers from attack power and such taken into account. 

### Fixed
- Fixed some issues that would cause attacks on the next swing to have their tooltips displayed slightly wonky. 

## [1.0.15-RC] 2019-08-11
### Changed
- The quest watcher is now visible again. We might write a prettier one later, this old one is kind of boring. 
- Improved the size and anchoring of the bag slot buttons beneath the backpack. 

## [1.0.14-RC] 2019-08-11
### Changed
- The durability frame is now placed more wisely. 

## [1.0.13-Alpha] 2019-08-11
### Changed
- Removed the "_Classic" suffix from the UI name in options menu. It doesn't need a different display name, because it's not a different UI, just for a different client. 
- Replaced the blip icon used to indicate what I thought was just resource nodes with a yellow circle with a black dot, as it apparently also is the texture used for identifying questgivers you can turn in finished quests too. Big purple star just didn't seem right there. 

## [1.0.12-Alpha] 2019-08-11
### Added
- Added minimap blip icons for 1.13.2! 
- Added styling to the up, down and to bottom chat window buttons. 

### Changed
- The GameTooltip now follows the same scaling as our own tooltips, regardless of the actual uiScale. 

## [1.0.11-Alpha] 2019-08-10
### Changed
- Disabled the coloring of the orb glass overlay, as this looked strange when dead or empty. None of those things seem to happen in retail. They do here, however. So now I noticed. 
- Disabled castbars on nameplates, as these can't be tracked through regular events in Classic. Any nameplate units would be treated as no unit given at all, which again would default to assuming the player as the unit, resulting in mobs often getting OUR casts on their castbars. We will be adding a combatlog tracking system for this later, which relies on unitGUIDs. 

### Fixed
- Fixed a bug when right-clicking the Minimap.

## [1.0.10-Alpha] 2019-08-10
### Added
- Hunters now get a mana orb too! 

## [1.0.9-Alpha] 2019-08-09
### Changed
- Removed all API calls related to internal minimap quest area rings and blobs.
- Removed a lot of unneeded client checks, as we're not checking for any retail versions anymore. 

## [1.0.8-Alpha] 2019-08-09
### Changed
- Removed more vehicle, override and possess stuff from the unitframe library. 

## [1.0.7-Alpha] 2019-08-09
### Changed
- Removed more petbattle and vehicle stuff from actionbutton library. 

## [1.0.6-Alpha] 2019-08-09
### Changed
- Disabled Raid, Party and Boss frames. Will re-enable Raid and Party when I get it properly tested after the launch. Did Boss frames exist? 

## [1.0.5-Alpha] 2019-08-09
### Fixed
- Fixed Rogue combo points. Cannot test Druids as they get them at level 20, and level cap here in the pre-launch is 15.

## [1.0.5-Alpha] 2019-08-09
### Fixed
- Fixed micro menu.
- Fixed option menu.
- Fixed aura updates on unit changes. 

## [1.0.3-Alpha] 2019-08-09
### Fixed
- Fixed typos in bindings module.
- Fixed API for castbars. 

## [1.0.2-Alpha] 2019-08-09
### Fixed
- Changed `SaveBindings` > `AttemptToAttemptToSaveBindings`, fixing the `/bind` hover keybind mode!

## [1.0.1-Alpha] 2019-08-09
- Public Alpha. 
- Initial commit.
