# AI Assist

AI Assist is a new-style (Lua-based) Supernull character. Its main gimmick is in providing a simple AI to the partner character. It achieves this by using Supernull techniques to analyze the partner's states and animations, and determine which states are useful for an AI. Then, during the match, it disables the character's default AI and controls it directly via Supernull.

## Restrictions

AI Assist is intended to play (loosely) within the rules and according to the character's intended play style. To that end, there's several things which would make the AI better which are intentionally NOT implemented:

- Directly reading the enemy's attacks and animations to find best counters (one exception: it will read animation 0 during analysis to understand opponent's height)
- Allowing the partner to enter states which aren't specifically permitted through the command file
- Allowing the partner to illegally run states which require power
- Moving the partner in ways not specified by their own states

## Inaccuracies

Despite the above restrictions, AI Assist does still cheat on certain portions of the implementation. This is mostly just to make my life easier developing it, but also helps to cover some weaknesses of characters which were never intended for AI vs AI play.

- AI Assist will attempt to manually determine which moves can be chained. It will try to follow a chain of Light > Med > Heavy > Super > Hyper. AI Assist guarantees it will never move backwards from e.g. Hyper to Super (assuming the HitDefs on the move are tagged properly). However, it may be inaccurate in guessing which moves are light/med/heavy depending on the way the HitDefs have been written.
- AI Assist will grant extra juggle points to the character. (This would probably be better as a config option?)
- AI Assist uses a forced custom state on the partner for movement options (mostly jumping forward/back) which may not exist in the source files (it's a direct rip of common1 though, so this is a bit less likely to be an issue).

## Future work

- Eval triggers from -1 directly to identify what moves are executable on each frame
- Better implementation of guard/movement