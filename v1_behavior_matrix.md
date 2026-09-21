# v1 behavior matrix

This is the compact rules and product contract for v1. It turns accepted
rules into scenarios that later model, controller, and UI tests can reuse.
`functional_spec.md` remains the detailed source of truth.

## Delivery boundaries

| Area | v1 contract | Current prototype status |
| --- | --- | --- |
| Players | One local human and fair AI opponents; validate the first complete flow with four total players. The design supports 4–10 total players. | The cleanup prototype is a synchronous automated simulation; human decisions arrive in Epic 3 and the table in Epic 4. |
| Bots | Shipping bots use public information plus their own hand. Perfect-information Optimal bots are simulation-only. | Random, Aggro, and Scared are the fair-policy baseline; final shipping lineup is selected through playtesting. |
| Cards | Four copies of each value from 1 through the starting player count. Suits retain identity for future presentation but have no base-game rule effect. | The current value-only simulation does not yet carry suit identity; that domain-data work belongs to Epic 2. |
| Company tokens | Public acquisition history only; they are neither currency nor a rule input. | Token transfer/removal presentation is deferred to the authoritative engine/UI work. |
| Network and expansions | No network transport, suit powers, event deck, spendable token economy, or cloud save is required. | Deferred beyond v1. |

## Action matrix

| Situation | Accepted result | Later invariant / fixture |
| --- | --- | --- |
| Setup | Deal every card, four cards per player; choose a living starting seat; preserve clockwise seat order. | Total active cards are `4 × starting players`; the selected seat takes turn one. |
| Offer | The actor chooses one card they own and a different living target. | Invalid actor, target, or offered card changes no state. |
| Exact single repayment | Target returns one card whose value equals the offer; both remain alive and exchange cards. | Cards remain conserved; stable same-value swap adds the provisional mirror boredom point. |
| Exact split repayment | For offer 3, target returns 1+2. Target receives the offered 3 and remains alive. | A legal split is not an acquisition and adds only normal boredom. |
| Overpayment | For offer 3, target may return 4 or 1+1+2. | Returned total is at least the offer; all selected physical cards are distinct. |
| Entire hand pays | If the target's entire hand reaches the offer, it may return all of it, receives the offered card, and remains alive. | An empty hand during a successful repayment is not elimination. |
| Duplicate values | A hand may contain repeated values. | Repayment selection removes only the selected copies, never every equal-valued card. |
| Failed repayment | If the target's full hand totals less than the offer, transfer every target card to the actor and eliminate the target. The offered actor card remains with that actor. | Acquirer receives only the target hand; the offered card was never transferred. |

## Market and terminal matrix

| Trigger | Result |
| --- | --- |
| Stable acquisition with more than one survivor | Start a warning for the current highest active value. The provisional length is one completed warning turn per survivor at warning start; the triggering turn is the first. |
| Play-based boredom threshold exceeded | Start the same warning. Stable normal trades add one boredom; only one-card equal-value swaps add a second. |
| Time-based countdown | The selected time-based policy starts the same warning after two full stable rounds without an elimination. An acquisition resets the countdown; the UI shows round and completed-turn progress. |
| Acquisition during warning | Transfer the target hand, check monopoly first, then immediately resolve the pending crash if more than one survivor remains. |
| Crash | Remove every card of the pending value simultaneously, bankrupt every player whose hand is then empty, return to stable, and reset boredom. Bankruptcies never queue a crash. |
| Monopoly | An acquisition or crash leaves exactly one survivor. That player wins immediately. Acquisition monopoly takes precedence over a pending crash. |
| Duopoly | Exactly two survivors, stable market, and each holds every active value from 1 through the current highest active value. Both survivors win. |
| Global Economic Meltdown | A crash leaves zero survivors. The game ends with an empty winner list. |
| Other endings | No score comparison, arbitrary turn cap, or three-plus-player hand-pattern ending exists in v1. A test turn cap reports a diagnostic failure. |

## Information and local-player experience

Public state includes player identity and survival, public hand sizes,
offer/repayment cards, eliminations, market state, crashes, and trade/event
history. A player sees only their own current hand; other hands and hand
totals are private. Development logs may expose hands only in debug builds.

If the local human is eliminated, the v1 interface offers spectating with
fast-forward or starting a new match. Quitting is not a scored result.
All essential human decisions must work by pointer and keyboard once the UI
is introduced.

## Provisional decisions to test

- Warning length: one completed warning turn per survivor at warning start.
- Play-based boredom: counter threshold `> 10 × living players`; one extra
  point only for a same-value, one-card swap.
- Time-based market: two full stable rounds without an elimination start the
  same warning, with an explicit round countdown.
- The fair shipping bot roster remains a playtest choice.
