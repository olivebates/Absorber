# Absorber: opening conversations

A large angry bull has taken over the nearby cave and blocked the route into the desert. The opening conversations give the player that immediate goal without introducing extra lore.

Four short character conversations establish the route, while one-time player remarks acknowledge gameplay milestones.

## 1. Meeting Nia

Nia warns the player that the cave's big angry bull blocks the way forward, then sends them to Asha to prepare.

## 2. Meeting Asha

Asha remains silent when approached. On the first interaction she welcomes the player back, invites them to inspect her stock, and then opens the shop. Later interactions open the shop immediately.

## 3. Meeting Lio

Lio remains silent when approached. On the first interaction he talks about the hard work of digging gold, jokes `If only I had some way to automate it, hah!`, mentions wanting fish, starts the gold-mine quest, then opens Lios Shop. Until the nearby mine is built, later interactions repeat that he wants a way to automate his gold digging.

## 4. Opening the first gate

After the bull falls and the gate opens, the player celebrates the victory.

## Companion recruitment

Buying Deru's Spare Cart Parts starts Asha's recruitment conversation. When Mira accepts, Asha's Store closes permanently and a full-screen celebration identifies her as the newly unlocked healing companion. `AshaJoins.mp3` starts immediately as the biome music quickly fades out. A text-height black banner enters from the right beneath Asha, followed at quarter-second intervals by her portrait, fading rotating sun rays, and the popping `Asha joins the party!` title. There are no explanatory lines beneath the title. The fanfare holds gameplay for at least three seconds, keeps the rays rotating, and then waits for any key or mouse click before returning control and restoring the biome music.

Giving the parts to Deru repairs his cart and recruits him instead of turning him into a shopkeeper. Deru deals 7 damage per hit while hunting eligible enemies throughout AreaID 2, carries stat rewards and item drops, and returns to the AreaID 2 campfire for the same reward-handoff loop used by Lio. Helpers also carry item drops. If Mira cannot fit everything, an inventory-transfer popup lets the player choose what to keep before confirmation clears the helper's item inventory. Small deliveries are free and large deliveries cost 3 Gems. Hovering either waiting helper at a campfire shows their carried rewards and price in an equipment-style popup.

## Quest log

The Quest Log opens from the `iconQuest` button aligned above the inventory. Lio's first conversation starts the Tiny Woods quest: build the mine next to him, build the two remaining gold mines, then recruit him. Deru's cart-parts story is the Snakemouth Expanse quest. Titles show their location in parentheses. The log shows every step through the current one, crosses out finished steps in red, and marks a completed quest with a green checkmark. Starting or advancing either quest sends a red dot from Mira into the button and makes it pulse as the update is absorbed.

## One-time remarks

Mira comments once upon coming within seven tiles of the cave bull, building each producer type, standing directly beside a campfire, crossing the former gate tile, reaching the second campfire, teleporting to a different campfire, and killing the Evil Goat at ChickenSpawn12. Building a mine on the gold rock nearest Lio prompts his two-line reaction. Mad Coyote's first snare produces the skill-sensitive escape prompt, and its first defeat celebrates clearing the path. Each shopkeeper's first successful purchase temporarily closes their shop for a one-time response, then reopens it.

## Presentation and triggers

- Every conversation contains no more than six messages.
- The opening plays when the player enters a three-tile radius around Nia, not when a new game starts.
- Asha and Lio speak only on their first direct interactions; proximity alone remains silent.
- The final conversation plays when the first gate opens.
- Interacting with Nia outside her story introduction plays one default line. Later Lio interactions open his store. Absorbing Health and enemy respawns do not trigger dialogue.
- The dialogue panel stays centered and fits its width to the current message, up to its wrapping limit.
- Mira's portrait and name appear unflipped on the left. NPC portraits and names appear on the right, with the portrait flipped toward the text; Asha is the exception and remains unflipped.
- All fox NPCs stop moving while the dialogue box is open.
- Story progress, every one-time-event flag, and Lio/Nia positions persist in saves.
