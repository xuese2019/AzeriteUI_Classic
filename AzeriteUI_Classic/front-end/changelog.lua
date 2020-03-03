local ADDON, Private = ...
local Changelog = {
	{
		tag = "1.0.104-RC",
		date = "2020-03-03",
		entries = {
			{
				header = "Added",
				items = {
					[[Added Rogue and Druid finishing moves spell highlighting when combo points are maxed out.]]
				}
			}
		}
	},
	{
		tag = "1.0.103-RC",
		date = "2020-03-01",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed an issue with the dispellable group frame debuff display that could cause an error when leveling up.]],
					[[Fixed an issue that could cause exact mob health values to not be displayed. This was related to API changes in the classic client that since February 18th 2020 now reveals exact mob health to the player, where we previously used RealMobHealth interaction to show this.]],
					[[Redid how it is decided whether a full health value is available or not.]],
					[[Made the clearcast highlight color brighter, as it wasn't standing enough out from its surroundings.]],
					[[Attempting to work around an issue that would cause a bug and require a `/reload` upon reaching level 60. A little hard to reproduce, though.]]
				}
			}
		}
	},
	{
		tag = "1.0.101-RC",
		date = "2020-02-29",
		entries = {
			{
				header = "Changed",
				items = {
					[[Actionbutton spell highlight alerts have been moved to a new back-end of its own.]],
					[[Actionbutton spell highlights have gotten new coloring. Clearcasts are now blue, reactive abilities bright yellow, finishing moves range.]],
					[[Added Shadow Bolt highlighting when Warlock Shadow Trance is active.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed an issue in the mana orb plugin that would sometimes cause it to be forcefully reshown even though the element had been disabled.]],
					[[Fixed an issue where a custom styling method would overwrite the minimap module's ring bar text display, and people hitting new experience- or reputation levels would still be seeing the "New" text.]]
				}
			}
		}
	},
	{
		tag = "1.0.99-RC",
		date = "2020-02-28",
		entries = {
			{
				header = "Added",
				items = {
					[[Mana users now now have the option to use the azerite crystal for all power types, instead of the mana orb.]],
					[[There are now mana bars visible for mana users on the group frames. Note that for non-healer units the bars will only become visible when the unit is running really low on mana.]],
					[[Chat spam on logon or manual reloads is now suppressed. This is a forced setting. The Guild Message of the Day will be shown after roughly 10-12 seconds after logging in or reloading the interface. Messages after zoning in or out of instances and other portals are not affected.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Most non-targeted nameplates should be more visible both in and out of combat now, making tanking and healing easier.]],
					[[The dispellable debuff display on group frames now checks if the character has high enough level to actually do the dispel.]],
					[[Debuffs on unit frames belonging to hostile units are now all colored red, as displaying the debuff type using color should only be used for dispelling purposes.]],
					[[Debuffs on hostile units not cast by the player is now desaturated.]],
					[[Buffs on friendly units not cast by the player is now desaturated.]],
					[[Auras are now sorted.]],
					[[Auras on the target frame when you target a boss now take advantage of the larger width of the frame. ]],
					[[The chat frame buttons should now always be visible if the frame isn't currently scrolled to the bottom of its content.]],
					[[When just having reached a new level, or reputation level if that is what you're current tracking, the minimap badge text should now be an asterisk `*`, and not the word "New". The latter was never intended, as we used a graphical exclamation mark in the retail version of this addon, but Blizzard changed that to the text "New" to better reflect how their quest dialogs looked in vanilla.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[When a group frame's unit changes while mouseovered, its tooltip should now properly update to show the new unit.]],
					[[When the target frame's unit changes during a cast or channel and the new unit isn't currently casting or channeling anything, its castbar should now properly be cleared.]]
				}
			}
		}
	},
	{
		tag = "1.0.98-RC",
		date = "2020-02-14",
		entries = {
			{
				header = "Added",
				items = {
					[[The pet bar now has similar fading options as the additional action buttons. So in addition to fully being able to toggle the pet bar, you can now choose its visibility between always, in combat and mouseover, or only on mouseover.]]
				}
			}
		}
	},
	{
		tag = "1.0.97-RC",
		date = "2020-02-14",
		entries = {
			{
				header = "Changed",
				items = {
					[[Player and target unit frames should now display two rows of auras, up from one.]]
				}
			}
		}
	},
	{
		tag = "1.0.96-RC",
		date = "2020-02-12",
		entries = {
			{
				header = "Added",
				items = {
					[[Added cooldowns to the pet bar.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Updated love festival dates for 2020.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[May or may not have fixed an issue with additional action buttons not fading properly.]]
				}
			}
		}
	},
	{
		tag = "1.0.95-RC",
		date = "2020-02-06",
		entries = {
			{
				header = "Added",
				items = {
					[[The pet buttons have been added to the `/bind` mode.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Actionbutton backdrops no longer become visible when you're holding a pet ability on the cursor. This was a remnant from retail where it's possible to put pet abilities on normal actionbars, something we cannot do in Classic.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[You should now be able to toggle autocasting of pet abilities by right-clicking the ability on the pet bar, or using your keybind.]],
					[[The Blizzard reputation watch bar should no longer invisibly interfere with your ability to click the bottom part of the action bars when you are tracking a reputation.]]
				}
			}
		}
	},
	{
		tag = "1.0.94-RC",
		date = "2020-02-03",
		entries = {
			{
				header = "Added",
				items = {
					[[Added the first draft of the pet bar. Finally you can order your pet around, do something else than just stand there while mindcontrolling opposing players, and even finish killing Emberstrife for your UBRS attunement quest without having to disable the addon mid fight.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Primary chat window buttons will now become visible when hovering over the window.]],
					[[Empty backdrops of actionbuttons will now be visible if there are visible buttons with content farther down along the bars. This is to prevent "holes" in the layout.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[PvP rank names in unit tooltips should no longer show your own faction's rank names on players from the opposite faction.]]
				}
			}
		}
	},
	{
		tag = "1.0.93-RC",
		date = "2020-01-29",
		entries = {
			{
				header = "Changed",
				items = {
					[[5 player party frames will no longer be used when player is in a raid group, even if that raid group has less than 5 total members. Party frames by default only show the raid subgroup you're in, leaving people placed in other groups invisible. This behavior was unintended, so we're sticking to party frames with portraits for parties, and smaller raid frames for any and all raid groups.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Finally fixed the small frame flickering after interrupted casts. This was an issue related to the frequent updates of frames lacking distinct unit events, like the ToT frame.]]
				}
			}
		}
	},
	{
		tag = "1.0.92-RC",
		date = "2020-01-29",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Party aura tooltips show now grow towards the right, instead of towards the left and straight out of the screen. Now you can read them.]]
				}
			}
		}
	},
	{
		tag = "1.0.91-RC",
		date = "2020-01-28",
		entries = {
			{
				header = "Added",
				items = {
					[[First draft of aura durations added. Better filtering and display coming this week! Yay!]]
				}
			}
		}
	},
	{
		tag = "1.0.90-RC",
		date = "2020-01-11",
		entries = {
			{
				header = "Added",
				items = {
					[[Spells that require reagents should now show their remaining reagent count when placed on the action bars.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Trying to work around some language issues that would cause placing items on the actionbar to sometimes bug out when hovering over them. The issue was related to different formatting of some game strings in English and non-English clients.]]
				}
			}
		}
	},
	{
		tag = "1.0.89-RC",
		date = "2020-01-09",
		entries = {
			{
				header = "Changed",
				items = {
					[[Added a forced update of all ToT unitframe elements on player target change, as this previously had up to half a second delay on player target changes when the ToT frame remained visible throughout the change.]]
				}
			}
		}
	},
	{
		tag = "1.0.88-RC",
		date = "2020-01-07",
		entries = {
			{
				header = "Added",
				items = {
					[[Added subgroup numbers to the bottom left part of the raid frames. No more headache trying to figure out who's in what group, or where the Alliance AV leecher you want to report is!]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed an issue with some raid frame elements like leader/assistant status as well as raid marks which sometimes only would update on a GUID change.]]
				}
			}
		}
	},
	{
		tag = "1.0.87-RC",
		date = "2020-01-05",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed a typo in the frFR translation that caused reputation tracking on frFR game clients to bug out.]]
				}
			}
		}
	},
	{
		tag = "1.0.86-RC",
		date = "2019-12-31",
		entries = {
			{
				header = "Added",
				items = {
					[[Added the very first experimental draft of our spell highlight system. Druids with Omen of Clarity will now find that Shred, Ravage, Maul and Regrowth are marked when their clearcast proc fires. This is a work in progress, and I'll expand the list for more classes, as well as write other methods into this system to light up reactive abilities like Warrior's Overpower and similar.]],
					[[Started on the nameplate aura blacklist. Certain spam like Mark of the Wild, Leader of the Pack and various other auras will no longer show up on party member nameplates. This too is a list in growth.]]
				}
			}
		}
	},
	{
		tag = "1.0.85-RC",
		date = "2019-12-18",
		entries = {
			{
				header = "Changed",
				items = {
					[[Expanded the group frame hitboxes to cover the bottom part of the health border as well. Super easy to select targets now.]],
					[[Further tuned the outline and shadow of both the raid warnings and error messages.]],
					[[Dispellable and boss debuffs visible on the group frames should should now always be fully opaque, even if the group frame itself is faded down from being out of range.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed an issue that prevented raid marks, leader- and assistant crowns as well as main tank and main assist icons from showing up on the raid frames.]]
				}
			}
		}
	},
	{
		tag = "1.0.84-RC",
		date = "2019-12-17",
		entries = {
			{
				header = "Changed",
				items = {
					[[Prettied up the raid warnings a bit more.]],
					[[Slightly trimmed the popups.]],
					[[Went for a more elegant fix for the bg popups, where instead of changing their text hide them completely. Now a flashing red message - in addition to the usual bg ready sound - will tell you how to enter the available battleground. This change is Tukz-inspired.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed the health value of group member pet tooltips, where their actual health value would be presented with a percentage sign behind. That was a visual bug, the value was their actual health all along.]]
				}
			}
		}
	},
	{
		tag = "1.0.83-RC",
		date = "2019-12-16",
		entries = {
			{
				header = "Changed",
				items = {
					[[Boss/dispellable debuff slot on group frames should no longer react to mouseover events. There won't be a tooltip anymore, but it won't be in the way of clicking on the unitframe to select it as your target anymore.]],
					[[RaidWarnings shouldn't look as freaky and warped anymore, as we have disabled certain very faulty scaling features the default user interface applies to these messages. We also changed the font slightly to make it more readably on action filled backgrounds in raid situations.]]
				}
			}
		}
	},
	{
		tag = "1.0.82-RC",
		date = "2019-12-15",
		entries = {
			{
				header = "Changed",
				items = {
					[[Fixing a wrong date in some secret code. No biggie, it'll fire tomorrow for those lacking this update. But I want pretty colors!]]
				}
			}
		}
	},
	{
		tag = "1.0.81-RC",
		date = "2019-12-14",
		entries = {
			{
				header = "Changed",
				items = {
					[[The minimap tracking button now changes position based on whether the BG eye is visible or not.]]
				}
			}
		}
	},
	{
		tag = "1.0.80-RC",
		date = "2019-12-12",
		entries = {
			{
				header = "Changed",
				items = {
					[[Removed the ability to enter BGs through the bugged popup. Now we'll have to learn to use the eye, or simply not get anywhere. I changed the text in the popup to reflect this new behavior. This is a temporary fix until I can figure out how to get a working BG entry popup again.]]
				}
			}
		}
	},
	{
		tag = "1.0.79-RC",
		date = "2019-12-11",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Both the Minimap button and BG entry popup should work... better, now.]]
				}
			},
			{
				header = "Removed",
				items = {
					[[Removed the popup styling. It's problematic right now.]]
				}
			}
		}
	},
	{
		tag = "1.0.78-RC",
		date = "2019-12-11",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed spam filter issues. Clearly chat events have changed since I was a young noob. Luckily this older noob figured it out.]]
				}
			}
		}
	},
	{
		tag = "1.0.77-RC",
		date = "2019-12-11",
		entries = {
			{
				header = "Changed",
				items = {
					[[Only apply our spam removal to system messages. That should be the correct message group.]]
				}
			}
		}
	},
	{
		tag = "1.0.76-RC",
		date = "2019-12-11",
		entries = {
			{
				header = "Added",
				items = {
					[[Added the Minimap Battlefield button. We're using our green groupfinder eye from the retail version of this addon.]],
					[[Added a minor chat filter to remove the "You're not in a raid group" spam that keeps happening within Battlegrounds. Cause can be other addons, but for now we're just filtering it out.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Slightly re-aligned the Minimap tracking button to make a little room for the new Battlefield button.]],
					[[Added back the Minimap blip textures, as they appear to be more or less unchanged from the previous patch.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[The Blizzard static popups will no longer be repositioned by us to accomodate our styling of them, as this was causing taint with the new Battleground popups, making the enter button unclickable. This change might cause some graphical overlap in situations with two popups visible at once, though this should be purely visual and not affect the ability to click the buttons. We'll come up with better styling soon.]]
				}
			}
		}
	},
	{
		tag = "1.0.75-RC",
		date = "2019-12-11",
		entries = {
			{
				header = "Added",
				items = {
					[[Added the keyring button to the backpack.]],
					[[Added in some groundwork for a couple of upcoming features.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Updated the TOC version to WoW Client Patch 1.13.3.]],
					[[Adjusted statusbar code to avoid a very subtle wobbling that nobody but me seem to have noticed.]]
				}
			}
		}
	},
	{
		tag = "1.0.74-RC",
		date = "2019-12-04",
		entries = {
			{
				header = "Fixed",
				items = {
					[[The chat window position should once again instantly update without needing to reload when the Healer Layout is toggled in the menu.]]
				}
			}
		}
	},
	{
		tag = "1.0.73-RC",
		date = "2019-11-29",
		entries = {
			{
				header = "Added",
				items = {
					[[Added back Blizzard's `/stopwatch` command. The stopwatch exists in Classic, so why not?]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Left-Clicking the clock now toggles the stopwatch.]],
					[[Casts should no longer appear to continue after the unit has died.]]
				}
			}
		}
	},
	{
		tag = "1.0.72-RC",
		date = "2019-11-20",
		entries = {
			{
				header = "Added",
				items = {
					[[Added in group tools with raid icon assignment, ready check and raid/party conversion buttons.]],
					[[Added player PvP titles to unit tooltips.]]
				}
			}
		}
	},
	{
		tag = "1.0.71-RC",
		date = "2019-11-20",
		entries = {
			{
				header = "Fixed",
				items = {
					[[The blizzard durability frame should once again be hidden, preventing double up when our own is shown.]]
				}
			}
		}
	},
	{
		tag = "1.0.70-RC",
		date = "2019-11-16",
		entries = {
			{
				header = "Added",
				items = {
					[[Tooltips should now display when units are civilians. Gotta stay clear of those Dishonorable Kills!]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Adjusted nameplate raid icon position to stop it from colliding with the auras.]],
					[[Tooltip health values now show a percentage sign when only percentage and not the real health value is available.]]
				}
			}
		}
	},
	{
		tag = "1.0.69-RC",
		date = "2019-11-08",
		entries = {
			{
				header = "Changed",
				items = {
					[[The HUD castbar is now anchored to the bottom rather than the center of the screen. It has also been moved farther down, to not be as much in the way.]],
					[[Removed the target level badge for most units.]],
					[[Added the target's level to its name text, like in the tooltips.]],
					[[Added the small target power crystal for all units that have power.]],
					[[Changed the small target power crystal to be slightly larger, and slightly more toned down.]]
				}
			}
		}
	},
	{
		tag = "1.0.68-RC",
		date = "2019-11-07",
		items = {
			[[_**DISCLAIMER:**_]],
			[[_Loss of limbs, life or sanity is not the responsibility of the author._]]
		},
		entries = {
			{
				header = "Changed",
				items = {
					[[There is now a new HUD entry in our options menu, where you can choose to disable the combo point display and the on-screen castbar.]],
					[[Added a highly experimental feature to work around the Blizzard issue where macro buttons sometimes are missing their info and icon until the macro frame is opened or the interface reloaded. This fix might cause the whole universe to implode, and you're thus installing this at your own risk.]]
				}
			}
		}
	},
	{
		tag = "1.0.67-RC",
		date = "2019-11-02",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Targeted high level hostile players should no longer get a wooden unit frame border, but instead the same spiked stone frame as max level units.]],
					[[Skinnable dead units should once more show that they can be skinned in the tooltips. This applies to both units that can be skinned for leather, as well as herbs or ore.]]
				}
			}
		}
	},
	{
		tag = "1.0.66-RC",
		date = "2019-10-29",
		entries = {
			{
				header = "Changed",
				items = {
					[[Started major reformatting of stylesheet and unitframe styling code structure. First step in changes that eventually will affect the whole addon.]],
					[[Every time you reach a new reputation standing or experience level and your current value in these are below one percent, the minimap badge tracking these will now show an exclamation mark instead of the non-localized "xp" or "rp" texts they used to show.]],
					[[Tooltips should now show dead players in spirit form as simply "Dead", not "Corpse".]],
					[[Tooltips now indicates the rare- or elite status of NPCs much better.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Health numbers and percentages should no longer be visible on critters with the tiny critter unitframe, even if they're above level one.]],
					[[Changed the way the blizzard gametooltip fonts are set to work around some alignment issues that arose in a recent version.]],
					[[Fixed an issue where the vendor sell price in some cases (e.g. AtlasLoot) would be displayed twice in the same tooltip.]]
				}
			}
		}
	},
	{
		tag = "1.0.65-RC",
		date = "2019-10-28",
		entries = {
			{
				header = "Changed",
				items = {
					[[Renamed the whole library system for classic, since some adventurous tinkerers kept mixing files from retail into the classic files, leading to a series of unpredictable issues.]],
					[[Tooltips should indicate a lot better when a unit is dead now.]]
				}
			}
		}
	},
	{
		tag = "1.0.64-RC",
		date = "2019-10-27",
		entries = {
			{
				header = "Changed",
				items = {
					[[Disable tooltip vendor sell prices when Auctionator or TradeSkillMaster is loaded. More addons will be added to this list.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed a tooltip issue where the wrong object type was assumed.]]
				}
			}
		}
	},
	{
		tag = "1.0.63-RC",
		date = "2019-10-25",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Item tooltips now show the correct vendor sell price for partially full item stacks.]]
				}
			}
		}
	},
	{
		tag = "1.0.62-RC",
		date = "2019-10-25",
		entries = {
			{
				header = "Added",
				items = {
					[[Added vendor sell prices to items when not at a vendor.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Mouseover unit tooltips should now be much more similar to our unitframe tooltips.]],
					[[Mouseover tooltips shouldn't have a different scale before and after hovering over a unit anymore.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed some tooltip parsing issues that would use the spell description as the spell cost in some cases where spells had a cost but not a range.]]
				}
			}
		}
	},
	{
		tag = "1.0.61-RC",
		date = "2019-10-22",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed an issue with wrongly named custom events which caused interrupted spellcasts to appear to still be casting.]]
				}
			}
		}
	},
	{
		tag = "1.0.60-RC",
		date = "2019-10-17",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed wrong field name causing a nil bug when channeled player spells were pushed back.]]
				}
			}
		}
	},
	{
		tag = "1.0.59-RC",
		date = "2019-10-16",
		entries = {
			{
				header = "Added",
				items = {
					[[Added in raid frames. Frames can be toggled through the menu, just like the party frames.]],
					[[Added the first draft of castbars to other units than the player.]]
				}
			}
		}
	},
	{
		tag = "1.0.58-RC",
		date = "2019-10-13",
		items = {
			[[Files have been added, remember to restart the game client!]]
		},
		entries = {
			{
				header = "Changed",
				items = {
					[[Added some slight filtering to party frame auras to make it easier for healers to heal.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Group frames should now spawn in the correct place after a reload when healer layout was enabled previously.]]
				}
			}
		}
	},
	{
		tag = "1.0.57-RC",
		date = "2019-10-09",
		entries = {
			{
				header = "Added",
				items = {
					[[Now compatible with RealMobHealth.]]
				}
			}
		}
	},
	{
		tag = "1.0.56-RC",
		date = "2019-10-08",
		entries = {
			{
				header = "Changed",
				items = {
					[[Now compatible with Plater Nameplates.]]
				}
			}
		}
	},
	{
		tag = "1.0.55-RC",
		date = "2019-10-08",
		entries = {
			{
				header = "Added",
				items = {
					[[Added in party frames. Might have undiscovered bugs. Frames can be toggled through our menu.]],
					[[Added the Healer Layout (previously known as Healer Mode) back in, now that we have party frames. This layout switches the positions of the group frames and chat frames, resulting in all friendly unit frames being grouped in the bottom left corner of the screen above the actionbars, making it easier for healers.]]
				}
			}
		}
	},
	{
		tag = "1.0.54-RC",
		date = "2019-10-08",
		items = {
			[[ToC updates.]]
		}
	},
	{
		tag = "1.0.53-RC",
		date = "2019-10-07",
		entries = {
			{
				header = "Changed",
				items = {
					[[Removed the immovable object also known as the Blizzard durability frame, and replaced it with our own that looks exactly the same but has the benefit of actually working without stupid bug messages about mafia anchor connections. Fuck you secure anchoring system. ]]
				}
			}
		}
	},
	{
		tag = "1.0.52-RC",
		date = "2019-09-27",
		entries = {
			{
				header = "Added",
				items = {
					[[Added reputation tracking to the minimap ring bars!]],
					[[Aura tooltips now show the magic school of the aura.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Aura tooltips no longer show the spellID. You don't need to see that.]],
					[[Various aura filter tweaks, and the beginning of the Druid aura overhaul in preparation of that. All classes will eventually be covered, and I'm starting with Druid since that is my main and something I currently have direct access to.]]
				}
			}
		}
	},
	{
		tag = "1.0.51-RC",
		date = "2019-09-25",
		entries = {
			{
				header = "Added",
				items = {
					[[Added a right-click menu to the minimap to select tracking when available.]],
					[[Added a tracking button to the minimap. When left-clicked, it displays a menu of the available tracking types, when right-clicked, it disables the current tracking.]]
				}
			}
		}
	},
	{
		tag = "1.0.50-RC",
		date = "2019-09-23",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Slight bug in yesterday's update that caused all auras to sometimes be hidden in combat. Working as intended with this fix. This too is temporary, as I'm currently in the process of overhauling the aura system with parsed combat log information to make it far more functional for Classic.]]
				}
			}
		}
	},
	{
		tag = "1.0.49-RC",
		date = "2019-09-22",
		entries = {
			{
				header = "Changed",
				items = {
					[[Slightly adjusted the player aura filter to be more responsive to combat changes, and to only show long duration buffs in combat when they have 30 seconds or less time remaining before running out. Debuffs are displayed as before. This is not "the final filter", it's just a minor tweak to improve the current for as long as that may remain.]]
				}
			}
		}
	},
	{
		tag = "1.0.48-RC",
		date = "2019-09-21",
		entries = {
			{
				header = "Changed",
				items = {
					[[Healer Mode currently disabled, as it made no sense to switch just the chat around without the group frames. We'll re-introduce this option later once the group frames are in place.]],
					[[Slightly increased the size of the actionbutton hit rectangles, to make the tooltips feel a bit more responsive when hovering over the buttons.]]
				}
			}
		}
	},
	{
		tag = "1.0.47-RC",
		date = "2019-09-18",
		entries = {
			{
				header = "Changed",
				items = {
					[[If Leatrix Maps or Enhanced World Map for WoW Classic is loaded, this addon won't interfere with the World Map anymore.]]
				}
			}
		}
	},
	{
		tag = "1.0.46-RC",
		date = "2019-09-17",
		entries = {
			{
				header = "Removed",
				items = {
					[[Removed our anti-spam chat throttle filter that was working fine in BfA, as it's fully borked in Classic and probably the cause of all the missing chat messages in new chat windows that people have been experiencing.]]
				}
			}
		}
	},
	{
		tag = "1.0.45-RC",
		date = "2019-09-16",
		entries = {
			{
				header = "Changed",
				items = {
					[[Switch the middle- and left mouse button actions on our config button, and made the tooltip a bit more directly descriptive.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed a potential nil bug in the quest tracker. I was unable to reproduce this, but put in a safeguard.]]
				}
			}
		}
	},
	{
		tag = "1.0.44-RC",
		date = "2019-09-11",
		entries = {
			{
				header = "Changed",
				items = {
					[[I made something just about twenty percent brighter then they needed to be. Now hush!]]
				}
			}
		}
	},
	{
		tag = "1.0.43-RC",
		date = "2019-09-10",
		entries = {
			{
				header = "Changed",
				items = {
					[[Disabling aura filters for now, until we can get a proper combat event tracking system in place, and maybe some durations for class abilities too.]]
				}
			}
		}
	},
	{
		tag = "1.0.42-RC",
		date = "2019-09-09",
		entries = {
			{
				header = "Changed",
				items = {
					[[Move the chat window slightly farther down the screen.]],
					[[Removed an unannounced experimental feature that I felt belonged in an addon of its own.]],
					[[Redid the scaling system to just be simpler.]]
				}
			}
		}
	},
	{
		tag = "1.0.41-RC",
		date = "2019-09-08",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed the wrong function call introduced in the previous build.]]
				}
			}
		}
	},
	{
		tag = "1.0.40-RC",
		date = "2019-09-08",
		entries = {
			{
				header = "Changed",
				items = {
					[[All target unit frames (except the tiny critter/novise frame) now shows the unit health percentage on the left side, and will only show the actual health value on the right side when it's currently available. For now that limits it to you, your pet, and your group.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed a forgotten upvalue in the target unit frame aura filter which prevented most auras from being shown in combat.]],
					[[Players will now see their health at level 1, they don't have to wait until level 2 anymore. Weird bug.]]
				}
			}
		}
	},
	{
		tag = "1.0.39-RC",
		date = "2019-09-05",
		entries = {
			{
				header = "Changed",
				items = {
					[[Changed some inconsistencies in the selection- and highlight coloring of the quest log.]]
				}
			}
		}
	},
	{
		tag = "1.0.38-RC",
		date = "2019-09-05",
		entries = {
			{
				header = "Added",
				items = {
					[[Added quest levels to the quest log.]],
					[[Added a minor blacklist to the red error messages, mainly filtering out redundant information that was visually available elsewhere in the interface, or just became highly intrusive and spammy. Because we know there's not enough Energy to do that. We know.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Using better quest difficulty coloring in the quest log, and not the slightly too easy looking default one.]],
					[[Improved the Explorer Mode logic for mana for druids, as well as prevented the fading while drinking.]]
				}
			}
		}
	},
	{
		tag = "1.0.37-RC",
		date = "2019-09-04",
		entries = {
			{
				header = "Added",
				items = {
					[[Added the command `/clear` to clear the main chat window. Because why not.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Most abilities should now have their resource cost displayed in the actionbar tooltips.]],
					[[The text on the power crystal showing druid mana in forms should now be colored red when very little mana is left.]]
				}
			}
		}
	},
	{
		tag = "1.0.36-RC",
		date = "2019-09-01",
		entries = {
			{
				header = "Added",
				items = {
					[[Added a "secret" feature to automate group invites and declines a bit. The commands `/blockinvites` and `/allowinvites` have been added, where the latter is the normal all manual mode, and the former is an automated mode where invites from wow friends, bnet friends and guild are automatically accepted, and everything else automatically declined. No options for this behavior exists as of yet, except the ability to turn it on. It is disabled by default, but there for those that me that are dead tired of brainless muppets spamming invites without ever uttering a single word.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Toned down the opacity and reduced the number of messages visible at once in the red error message frame. Because I get it, there's not enough energy to do that now. I get it.]],
					[[Slightly tuned the tracker size and position for better alignment with everything else. You probably didn't even notice it, so subtle was it.]],
					[[The World Map now becomes slightly transparent when the player is moving. Just feels better to not completely block out the center of the screen when traveling from place to place on a fresh and very ganky PvP realm.]]
				}
			}
		}
	},
	{
		tag = "1.0.35-RC",
		date = "2019-08-31",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Locked the main chat in a manner not affecting its DropDown, thus preventing taint from spreading to the Compact group frames.]]
				}
			}
		}
	},
	{
		tag = "1.0.34-RC",
		date = "2019-08-31",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed a typo causing the UI to bug out when your pet was just content, not happy. I thought this was a feature? :)]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Made the aura filters even less filterish. We need actual lists here, since we can't check any real meta info of units not in our group. Will get myself up a few levels, then take a day to get this right!]],
					[[Removed the 3 limit buff cap on the target frame aura element. When you're a healer, you probably need to see more than just 3 happy ones.]],
					[[Added an extra row of auras to the target frame, just to make sure we don't miss stuff while the filters are unfilterish.]]
				}
			}
		}
	},
	{
		tag = "1.0.33-RC",
		date = "2019-08-31",
		entries = {
			{
				header = "Added",
				items = {
					[[Added an experimental feature to show spell rank on actionbuttons when more than one instance of the spell currently exists on your buttons.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Made the difference between usable and not usable spells more distinct.]]
				}
			}
		}
	},
	{
		tag = "1.0.32-RC",
		date = "2019-08-30",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed a typo causing an error when summoning pets.]]
				}
			}
		}
	},
	{
		tag = "1.0.31-RC",
		date = "2019-08-30",
		entries = {
			{
				header = "Changed",
				items = {
					[[Fixed some aura border coloring inconsistencies, as well as applied debuff type coloring to most auras that have a type.]]
				}
			}
		}
	},
	{
		tag = "1.0.30-RC",
		date = "2019-08-30",
		entries = {
			{
				header = "Fixed",
				items = {
					[[There should no longer be any misalignment when mousing over the world map to select zones.]]
				}
			}
		}
	},
	{
		tag = "1.0.29-RC",
		date = "2019-08-30",
		entries = {
			{
				header = "Added",
				items = {
					[[Added a fix for players that suffered from AzeriteUI not loading because they mistakingly has TukUI or ElvUI installed. AzeriteUI should now load anyway, despite that horrible addon list.]]
				}
			}
		}
	},
	{
		tag = "1.0.28-RC",
		date = "2019-08-30",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Player PvP icon should now properly be hidden while engaged in combat, to make room for the combat indicator.]]
				}
			}
		}
	},
	{
		tag = "1.0.27-RC",
		date = "2019-08-30",
		entries = {
			{
				header = "Added",
				items = {
					[[Added Pet Happiness as an experimental message to the bottom of the screen.]]
				}
			}
		}
	},
	{
		tag = "1.0.26-RC",
		date = "2019-08-29",
		entries = {
			{
				header = "Added",
				items = {
					[[Added a player PvP icon. It is placed where the combat indicator is, and thus hidden while in combat.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[Made the world map smaller, and stopped it from blocking out the world. We are aware that the overlay to click on zones is slightly misaligned, working on that.]],
					[[Changed the aura filters to be pretty all inclusive. Will tune it for classic later on.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed the display of Druid cat form combo points. It should now appear. If you're wondering why the points disappear everytime you change target, that's not a bug. That's a classic feature.]],
					[[Fixed a bug when opening the talent window.]],
					[[Fixed a lot of small issues and bugs related to auras and castbars.]]
				}
			},
			{
				header = "Removed",
				items = {
					[[Disabled all castbars on frames other than the player and the pet. We will add a limited tracking system for hostile player casts by tracking combat log events later on.]]
				}
			}
		}
	},
	{
		tag = "1.0.16-RC",
		date = "2019-08-12",
		entries = {
			{
				header = "Changed",
				items = {
					[[The quest tracker now looks far more awesome.]],
					[[The texture for active or checked abilities on the action buttons will now be hidden if the red auto-attack flash is currently flashing, making everything far easier to see and relate to.]],
					[[Made the tooltip for auto-attack much more interesting, as it now shows your main- and off hand damage, attack speed and damage per second. Just like the weapon tooltips in principle, but with actual damage modifiers from attack power and such taken into account.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed some issues that would cause attacks on the next swing to have their tooltips displayed slightly wonky.]]
				}
			}
		}
	},
	{
		tag = "1.0.15-RC",
		date = "2019-08-11",
		entries = {
			{
				header = "Changed",
				items = {
					[[The quest watcher is now visible again. We might write a prettier one later, this old one is kind of boring.]],
					[[Improved the size and anchoring of the bag slot buttons beneath the backpack.]]
				}
			}
		}
	},
	{
		tag = "1.0.14-RC",
		date = "2019-08-11",
		entries = {
			{
				header = "Changed",
				items = {
					[[The durability frame is now placed more wisely.]]
				}
			}
		}
	},
	{
		tag = "1.0.13-Alpha",
		date = "2019-08-11",
		entries = {
			{
				header = "Changed",
				items = {
					[[Removed the "_Classic" suffix from the UI name in options menu. It doesn't need a different display name, because it's not a different UI, just for a different client.]],
					[[Replaced the blip icon used to indicate what I thought was just resource nodes with a yellow circle with a black dot, as it apparently also is the texture used for identifying questgivers you can turn in finished quests too. Big purple star just didn't seem right there.]]
				}
			}
		}
	},
	{
		tag = "1.0.12-Alpha",
		date = "2019-08-11",
		entries = {
			{
				header = "Added",
				items = {
					[[Added minimap blip icons for 1.13.2!]],
					[[Added styling to the up, down and to bottom chat window buttons.]]
				}
			},
			{
				header = "Changed",
				items = {
					[[The GameTooltip now follows the same scaling as our own tooltips, regardless of the actual uiScale.]]
				}
			}
		}
	},
	{
		tag = "1.0.11-Alpha",
		date = "2019-08-10",
		entries = {
			{
				header = "Changed",
				items = {
					[[Disabled the coloring of the orb glass overlay, as this looked strange when dead or empty. None of those things seem to happen in retail. They do here, however. So now I noticed.]],
					[[Disabled castbars on nameplates, as these can't be tracked through regular events in Classic. Any nameplate units would be treated as no unit given at all, which again would default to assuming the player as the unit, resulting in mobs often getting OUR casts on their castbars. We will be adding a combatlog tracking system for this later, which relies on unitGUIDs.]]
				}
			},
			{
				header = "Fixed",
				items = {
					[[Fixed a bug when right-clicking the Minimap.]]
				}
			}
		}
	},
	{
		tag = "1.0.10-Alpha",
		date = "2019-08-10",
		entries = {
			{
				header = "Added",
				items = {
					[[Hunters now get a mana orb too!]]
				}
			}
		}
	},
	{
		tag = "1.0.9-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Changed",
				items = {
					[[Removed all API calls related to internal minimap quest area rings and blobs.]],
					[[Removed a lot of unneeded client checks, as we're not checking for any retail versions anymore.]]
				}
			}
		}
	},
	{
		tag = "1.0.8-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Changed",
				items = {
					[[Removed more vehicle, override and possess stuff from the unitframe library.]]
				}
			}
		}
	},
	{
		tag = "1.0.7-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Changed",
				items = {
					[[Removed more petbattle and vehicle stuff from actionbutton library.]]
				}
			}
		}
	},
	{
		tag = "1.0.6-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Changed",
				items = {
					[[Disabled Raid, Party and Boss frames. Will re-enable Raid and Party when I get it properly tested after the launch. Did Boss frames exist?]]
				}
			}
		}
	},
	{
		tag = "1.0.5-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed Rogue combo points. Cannot test Druids as they get them at level 20, and level cap here in the pre-launch is 15.]]
				}
			}
		}
	},
	{
		tag = "1.0.5-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed micro menu.]],
					[[Fixed option menu.]],
					[[Fixed aura updates on unit changes.]]
				}
			}
		}
	},
	{
		tag = "1.0.3-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Fixed typos in bindings module.]],
					[[Fixed API for castbars.]]
				}
			}
		}
	},
	{
		tag = "1.0.2-Alpha",
		date = "2019-08-09",
		entries = {
			{
				header = "Fixed",
				items = {
					[[Changed `SaveBindings` > `AttemptToAttemptToSaveBindings`, fixing the `/bind` hover keybind mode!]]
				}
			}
		}
	},
	{
		tag = "1.0.1-Alpha",
		date = "2019-08-09",
		items = {
			[[Public Alpha.]],
			[[Initial commit.]]
		}
	}
}
