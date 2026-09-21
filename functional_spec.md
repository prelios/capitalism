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

The primary thematic victory is monopoly: one surviving player. The other
v1 terminal outcomes are a stable two-player duopoly and no-winner Global
Economic Meltdown; score-based endings are future material.

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

#### Provisional warning timing

The warning duration is configured as a number of **completed warning
turns per survivor when the warning begins**. The provisional setting is
one turn per survivor. The survivor count is captured when the warning
starts; later eliminations or bankruptcies do not extend or shorten its
deadline.

The triggering turn is the first completed warning turn. At that turn's
finalization, the model announces the remaining count, decrements it, and
resolves the crash immediately if it reaches zero. This applies equally to
a stable-market acquisition and to boredom. The triggering action itself
has already resolved before the warning begins, so all players see the
pending value during that action's turn finalization.

For example, an acquisition leaves four survivors while the market is
stable. The warning begins with a count of four. Finalization of that
acquisition turn announces 4, then later completed turns announce 3, 2,
and 1. The count reaches zero at the end of the fourth warning turn, so
the crash removes the pending value before another turn starts. The same
sequence applies when boredom starts the warning. The setting is
provisional for playtesting; presentation may expose it as an exact count
or qualitative pressure.

An acquisition during a warning does not consume another warning turn:
after normal acquisition transfer and monopoly precedence, it immediately
resolves the existing crash. A crash that bankrupts the current player
removes that player atomically; the next turn selects the next living seat
clockwise from the bankrupt player's original seat. Bankruptcy never starts
or queues another warning.

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

If a crash removes all remaining players, the game ends immediately in
**Global Economic Meltdown** (working name). It has no winners. This is
not a score tie.

## 10. Market pacing

At match setup, the local player chooses one of two contraction policies.
The choice applies only to how a stable market starts an instability warning;
warning timing, crashes, bankruptcies, monopoly, duopoly, and meltdown rules
remain identical.

### Play-based market

The play-based counter is the provisional v1 contraction policy. On a
successful trade while the market is stable, boredom increases by 1. A
same-value, one-card-for-one-card swap adds one further point. An exact
split repayment is not a mirror: offering 3 and receiving 1+2 adds only
the normal point. Overpayment also adds only the normal point.

The current threshold is strictly greater than:

`BOREDOM_MULTIPLIER × living players`, with `BOREDOM_MULTIPLIER = 10`.

The model evaluates that threshold during turn finalization. If it is
exceeded, it starts a warning using the completed-turn timing in section 9.
Acquisition resets boredom as it starts or resolves instability. A crash
resets boredom after its atomic bankruptcy processing. During an active
warning, trades do not accumulate boredom; the pending crash is the only
market transition in progress.

This is the v1 contraction mechanism. It replaces a crude maximum-turn
cutoff; a simulation turn cap is diagnostic evidence of a fault, never a
game result.

### Time-based market

The time-based policy ignores trade shape. If two full stable rounds pass
without an elimination, it starts the same warning. A round begins with the
current living-seat order and completes once every player alive when that
round began has either completed one turn or been eliminated; newly
eliminated seats are skipped and do not restart the round. Any acquisition
resets the round countdown. The player-facing market panel shows the exact
round and completed-turn progress toward the two-round trigger.

### Play-based UI presentation

The engine may maintain an integer counter without showing that exact
integer. Player-facing states could instead communicate stable market,
increasing pressure, instability warning, and crash.

### Playtest comparison

Playtesting should compare whether players understand the qualitative
play-based feedback versus the explicit two-round countdown, whether
same-card swaps feel like deliberate stalling, how often warnings occur,
and whether either approach causes unproductive downtime.

## 11. Equilibrium

Earlier designs attempted explicit equilibrium detection. Testing showed
that a structurally "stable" hand distribution with three or more players
can still be broken by a legal suboptimal trade. Therefore such a snapshot
never ends a v1 match; boredom-driven market contraction is its only
anti-stagnation path.

Two players are the deliberate exception. A stable two-player market is a
**duopoly equilibrium** when each survivor holds at least one card of every
active value from `1..current highest active value`. The game ends with
both survivors as winners. An unstable market never qualifies, and merely
having the same number of distinct cards is insufficient if either player
is missing an active value.

## 12. Ending and victory

### Monopoly

After every acquisition and after each atomic crash resolution, determine
the surviving players exactly once. If exactly one player remains alive,
the game ends immediately and that player wins by **monopoly**. In
particular, an acquisition that leaves one survivor wins before a pending
market crash can remove cards from the acquirer.

### Global Economic Meltdown

If an atomic market crash removes every remaining player, the game ends
in **Global Economic Meltdown** (working name), with an empty winner list.
No player wins by score. The model must not advance the turn or emit a
second ending event after either terminal outcome.

### Duopoly equilibrium

If exactly two players remain, the market is stable, and both players meet
the two-player equilibrium condition in section 11, the game ends in a
**Duopoly**. Both survivors are winners; all previously eliminated players
remain losers. Monopoly and Global Economic Meltdown retain their stated
precedence when either applies.

### Future material

Score comparison, consensual endings, and other non-monopoly endings beyond
the defined duopoly equilibrium are outside v1. They may be reconsidered in
a future rules contract, but are not requirements for the base game.

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
9.  Selectable play-based or time-based instability pacing.
10. Monopoly, stable two-player Duopoly, and no-winner Global Economic
    Meltdown.
11. Public event/trade log.
12. Basic game-over UI.

Do **not** make the initial GUI dependent on animations, drag-and-drop,
artwork, suit powers, event decks, token economics, equilibrium detection
for three or more players, or networking.

## 22. Open decisions / configuration points

Do not silently hard-code these as final design decisions:

-   Exact instability warning duration.
-   Final boredom threshold/multiplier.
-   Whether mirror/equal-value trades add extra boredom and their exact definition.
-   Whether boredom is shown exactly or qualitatively.
-   Which AI personalities ship.
-   Whether global suit events are implemented.
-   Final recommended player count within 4-10.

## 23. v1 behavior matrix

Concrete v1 examples and the current delivery boundaries are collected in
[v1_behavior_matrix.md](v1_behavior_matrix.md). This matrix is a compact
companion to the detailed rules above; where they disagree, the confirmed
rules in this specification control.
