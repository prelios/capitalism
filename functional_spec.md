# Capitalism --- Functional Game Specification

**Status:** Prototype / implementation reference\
**Purpose:** Business and functional description for implementing the
digital game.

## 1. Product concept

*Capitalism* is a turn-based multiplayer card game about
accumulation, hostile acquisition, market instability, and eventual
consolidation.

The core rules are deliberately small. Most depth should come from
hidden information, public trading history, targeting, negotiation,
alliances, threats, and betrayal rather than numerous card effects.

The intended primary experience is human multiplayer. AI is useful for
simulation, prototyping, filling seats, and potentially later as bots.

A central design principle is that **wealth creates leverage**. Strong
players can prey on weaker players and acquisitions can snowball. This
is intentional. Market instability provides counter-pressure by
periodically destroying the highest-valued assets.

The primary thematic victory is monopoly: one surviving player. Because
monopoly need not occur every game, a score-based ending is also
supported.

## 2. Players and expected game shape

-   Hard minimum: **4 starting players**.
-   Soft maximum: **10 starting players**.
-   The rules scale mathematically beyond 10, but this is not a product goal.
-   Typical simulations have taken roughly **30-60 turns**.
-   Monopoly occurred in roughly **10-20%** of broad simulation sets; four-player games were lower (observed maximum around 7%).
-   Human duration is tentatively expected around **20-30 minutes**, pending playtesting.

These are prototype observations, not contractual balance targets.

## 3. Cards and market size

Let `N` be the number of starting players.

-   4 suits/categories.
-   Values `1..N`.
-   4 copies of each value.
-   Total deck size: `4 × N`.
-   Every player starts with exactly 4 cards.
-   The entire deck is dealt.

### Suits

In the **base game**, suits have no mechanical effect. Only numerical
value matters.

A themed release may call the four suits:

-   **Money**
-   **Workers**
-   **Tech**
-   **Hype**

The data model should preserve suit identity so optional variants can use it later.

## 4. Setup

1.  Determine starting player count `N`. Each player is given (or chooses) a company token.
2.  Construct four cards of every value `1..N`.
3.  Shuffle.
4.  Deal exactly 4 cards to every player.
5.  Select the starting player randomly.
6.  Establish fixed cyclic/clockwise turn order.
7.  Begin with the starting player.

Eliminated players are skipped thereafter.

## 5. Information model

### Hidden

-   A player's current hand is private to that player.

### Public

-   Trade initiator and target.
-   Offered card.
-   Every returned card.
-   Eliminations.
-   Market-instability state and crashes.
-   Survival status.
-   Public hand sizes.
-   Trade/event history.

Because trades are public, attentive players can infer hands over time.
This is intentional; the game should not automatically reveal inferred information.

## 6. Turn structure

On Player A's turn:

1.  A chooses any other **living** Player B.
2.  A publicly offers exactly **one card** from A's hand.
3.  B must return **one or more cards** whose combined value is greater than or equal to the offered value.
4.  If B can satisfy the offer, B receives A's offered card and A receives B's selected cards.
5.  If B cannot satisfy the offer even using B's entire hand, B is eliminated. A receives all of B's cards.
6.  Resolve resulting state changes.
7.  Advance to the next surviving player.

A player cannot target themselves. There is no voluntary pass in the base rules.

## 7. Repayment

For offered value `V`, a legal repayment is any subset of the target's
hand satisfying:

`sum(returned values) >= V`

Overpayment is legal.

For an offered `3`, examples include `3`, `1+2`, `4`, and `1+1+2`.

### Human choice

A human target chooses any legal repayment.
The engine must not force the cheapest subset.

### Baseline AI

Prototype AI generally:
1. Pays an exact match if possible.
2. Otherwise chooses the subset with the smallest total greater than the offer.
3. Is eliminated if no subset can reach the offer.

Tie-breaking among equally valued subsets is AI policy, not a core rule.

## 8. Elimination / acquisition

If B cannot satisfy A's offer:

1.  B gives **all remaining cards** to A.
2.  B is eliminated and takes no further turns.
3.  A is recorded as B's acquirer/killer.
4.  The elimination contributes to market instability.
5.  Check for monopoly.

Snowballing from acquisition is intentional.

### Acquisition history

The UI displays public "company tokens" showing acquisitions.
These are informational/thematic, not currency.

An eliminated player's previously acquired tokens are transferred to their acquirer,
representing acquisition of the whole conglomerate.

## 9. Market instability

Market instability is the systemic contraction mechanism. It prevents
indefinite stagnation, creates risk around high-value assets, and gives
players a "hot potato" window before valuable cards disappear.

The unstable value is the **current highest active card value**.

When destruction resolves:

> **ALL cards of that value are removed from play, regardless of owner.**

Example: in a six-player game, a crash of value 6 removes every
remaining 6. The effective market becomes 1-5. A later crash may remove
all 5s.

### Delayed destruction

Instability does not destroy cards immediately. A warning period allows
normal play and trading of unstable cards.

The model should explicitly represent:
- whether instability is active;
- the unstable value;
- when the warning period resolves.

The exact warning duration remains configurable pending playtesting.

### Elimination During Market Instability

If a player is eliminated through a failed trade while the market is already unstable:

1. Resolve the acquisition normally:
   - The eliminated player's cards transfer to the acquiring player.
   - The eliminated player's company tokens transfer to the acquiring player.
2. Immediately resolve the current market crash.
3. Remove ALL cards of the currently unstable value from every player's hand, including cards just acquired.
4. The market returns to a stable state.
5. Reset boredom/stagnation.

The elimination does **not** queue or trigger instability for the next-highest value.

Therefore:

- Elimination while market is stable → starts market instability.
- Elimination while market is unstable → immediately resolves the current market crash.

This makes further acquisitions during the instability warning period capable of bringing the pending crash forward.

### Bankruptcy Due to Market Crash

A player whose hand becomes empty because of a market crash is **bankrupt**.

Bankruptcy removes the player from the game, but is distinct from acquisition:

- No other player receives the bankrupt player's cards.
- No player is credited with eliminating/acquiring them.
- Their company/acquisition tokens are removed from the game rather than transferred.
- Bankruptcy does **not** trigger another market instability or another crash.

Crash resolution is atomic:

1. Remove ALL cards of the unstable value from all hands simultaneously.
2. Determine all players whose hands are now empty.
3. Declare those players bankrupt simultaneously and remove them from turn order.
4. Return the market to a stable state.
5. Reset boredom/stagnation.
6. Check the game-ending conditions.

Multiple players may therefore become bankrupt in the same crash.

If a crash removes all remaining players, the game ends without a monopoly winner.
Under score-based resolution, all affected players have a final card value of 0 and therefore tie unless another future rule specifies otherwise.

## 10. Stagnation / boredom

The digital prototype uses boredom to trigger contraction when ordinary
trading continues too long without a significant event.

Historical implementation:

`threshold = BOREDOM_MULTIPLIER × living_players`

with `BOREDOM_MULTIPLIER = 10`.

Conceptually:
- Ordinary turns increase boredom.
- Eliminations and instability/crash events reset or resolve stagnation.
- Reaching the threshold triggers market instability.
- This replaced a crude maximum-turn cutoff and eliminated indefinitely running simulations.

Timed instability appeared in roughly 4--20% of prior normal simulations.

### Mirror/equilibrium-like trades

A candidate refinement:
- Normal completed turn: `+1 boredom`.
- Equal-value/mirror-like trade: additional `+1 boredom`.

This is intended to accelerate contraction during repetitive
value-preserving play. **The exact modifier and definition are
provisional.**

### UI presentation

The engine may maintain an integer counter without showing that exact
integer. Player-facing states could instead communicate stable market,
increasing pressure, instability warning, and crash.

### Alternative

A simpler alternative (pending playtesting) may be to allow 1-2 full rounds of "stable market" play.
If, after 1-2 rounds, no elimination has occurred, the market becomes unstable.
Playtesting will reveal if this obvious counter is better than the more hidden boredom counter.

## 11. Equilibrium

Earlier designs attempted explicit equilibrium detection. Testing showed
that a structurally "stable" hand distribution can still be broken by a
legal suboptimal trade.

Therefore:
- Do not assume a snapshot pattern proves permanent equilibrium.
- Equilibrium is **not a victory condition**.
- Boredom/market contraction is the preferred general anti-stagnation mechanism.
- Explicit confirmation logic, particularly for a two-player endgame, remains an unresolved option rather than a core requirement.

## 12. Ending and victory

### Monopoly

If exactly one player remains alive, the game ends immediately and that
player wins by **monopoly**.

### Non-monopoly ending

A match may also end without monopoly through a supported stagnation/end
condition or, in human play, consensual termination.

Then:
1. Sum the numerical values of each surviving player's hand.
2. Highest total wins.
3. Ties are allowed.

Eliminated players do not compete for score victory in the base game.

## 13. Negotiation

Players may freely:
- make promises;
- form temporary alliances;
- coordinate attacks;
- threaten retaliation;
- bluff;
- lie;
- betray agreements.

The rules engine does **not** enforce such agreements.

Online voice/text communication is a product/platform concern, not
authoritative game logic.

## 14. AI personalities

AI policy must remain separate from legal action/resolution.

### Random

-   No privileged knowledge.
-   Random living target.
-   Random offered card.
-   Efficient repayment.

### Aggro

-   Uses public hand sizes, not hidden hands.
-   Targets the smallest hand.
-   Offers highest card.
-   Efficient repayment.

### Scared

-   Uses public hand sizes, not hidden hands.
-   Targets the smallest hand.
-   Offers lowest card.
-   Efficient repayment.

### Optimal family

Simulation/perfect-information agents that may know all hands:
- Avoid unproductive mirror offers.
- Try to offload cards due for destruction.
- **OptiHigh:** highest value-card offer.
- **OptiLow:** lowest value-card offer.
- **OptiRand:** random card offer.

These should not be presented as fair human-equivalent bots unless
deliberately designed that way.

## 15. Optional expansion modules

These should remain isolated from the base rules.

### Global suit events

Money, Workers, Tech and Hype may become mechanically relevant through
an optional global-events module.

Examples: credit crisis, worker shortage, tech boom, speculative bubble.

An event applies **globally**, not per player, and may temporarily
modify effective values, e.g. Money `+1`, Workers `-1`, Tech `+1`.

Possible duration: one round or until the next crash.

If implemented, effective-value calculation should be centralized so
trade validation, AI, scoring and UI cannot disagree.

### Suit-based trade restrictions

A proposed variant could prohibit certain same-suit trades, e.g. "Hype
cannot buy Hype." This is not accepted as a core feature and is lower
priority than global events.

### Token economy

An earlier proposal used spendable tokens and a central pot. It adds
bookkeeping and is **not recommended for the base game**.
Informational company tokens are preferred.

## 17. Functional architecture

### GameModel / GameState

Owns authoritative rules and state:
- players and survival;
- hands;
- setup;
- turn order/current player;
- trade validation/resolution;
- elimination;
- instability/destruction;
- boredom;
- end detection;
- scoring;
- public event history.

**Rule:** if it changes authoritative state or can affect who wins, it
belongs in the domain/model layer.

### GameController / Match Orchestrator

Owns process:
- starting matches;
- requesting human/AI actions;
- submitting actions to the model;
- advancing turns;
- coordinating "waiting for input"/AI process states;
- wiring model events to presentation.

It should not duplicate game rules.

### UI

Owns:
- public state;
- local private hand;
- target/card/repayment selection;
- logs;
- market-status presentation;
- game-over presentation.

UI submits **intent** and does not directly mutate authoritative state.

### AI

Consumes an allowed view of state and chooses legal actions.
Policy is separate from resolution.

## 18. Important domain events

Useful observable events include:
- turn started;
- trade proposed;
- trade resolved;
- player eliminated/acquired;
- market instability started;
- market instability updated;
- market value destroyed/crash resolved;
- turn ended;
- game ended.

Events announce what happened; they should not replace rule execution.

## 19. Multiplayer authority

The architecture should remain compatible with an authoritative multiplayer match:
- clients are not trusted to validate trades/elimination;
- clients receive only hidden information they are authorized to see;
- public events are broadcast;
- submitted actions are validated authoritatively;
- random setup is authoritative;
- AI and humans should ideally use the same action interface.

Networking need not be part of the first GUI prototype, but the domain
should not be coupled to a local UI.

## 20. Base-game invariants

1.  Every active card is owned by exactly one living player unless destroyed.
2.  At setup, every player owns exactly 4 cards.
3.  Initial values lie in `1..N`.
4.  A successful normal trade conserves cards in play.
5.  Exactly one offered card transfers from initiator to target.
6.  A legal repayment totals at least the offer.
7.  An eliminated player owns no active cards afterward.
8.  Eliminated players never take another turn.
9.  A crash removes **every active card** of the destroyed value.
10. Destroyed cards never return in the base game.
11. The active player is alive.
12. Players cannot target themselves.
13. Monopoly exists iff exactly one player remains alive.
14. Base-game suit identity never affects value or legality.
15. Another player's private hand is absent from a normal player information view.

## 21. Initial digital implementation scope

Prioritize a complete ugly-but-playable match:

1.  Setup for 4-10 players.
2.  Headless authoritative state/turn progression.
3.  Public player info and private local hand.
4.  Human target/card selection.
5.  Human repayment selection.
6.  Random AI turns.
7.  Trade resolution/elimination.
8.  Delayed instability and destruction of all highest-value cards.
9.  Boredom-triggered instability.
10. Monopoly and score-based ending.
11. Public event/trade log.
12. Basic game-over UI.

Do **not** make the initial GUI dependent on animations, drag-and-drop,
artwork, suit powers, event decks, token economics, complex equilibrium
detection, or networking.

## 22. Open decisions / configuration points

Do not silently hard-code these as final design decisions:

-   Exact instability warning duration.
-   Final boredom threshold/multiplier.
-   Whether mirror/equal-value trades add extra boredom and their exact definition.
-   Whether boredom is shown exactly or qualitatively.
-   Whether explicit equilibrium/end detection is needed, especially at two players.
-   Exact digital non-monopoly termination mechanism.
-   Which AI personalities ship.
-   Whether global suit events are implemented.
-   Final recommended player count within 4-10.
