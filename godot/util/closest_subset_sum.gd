extends RefCounted

class_name ClosestSubsetSum


static func closest_subset_cards(cards: Array[Card], target: int) -> Array[Card]:
	return closest_subset_cards_acc(cards, target, 0, [])


static func closest_subset_cards_acc(cards: Array[Card], target: int, accumulated_value: int, selected: Array[Card]) -> Array[Card]:
	var best: Array[Card] = []
	for index in cards.size():
		var card := cards[index]
		var candidate: Array[Card] = selected.duplicate()
		candidate.append(card)
		var candidate_value := accumulated_value + card.value
		if candidate_value >= target:
			if best.is_empty() or Player.cards_value(candidate) < Player.cards_value(best):
				best = candidate
			continue
		var remaining: Array[Card] = cards.duplicate()
		remaining.remove_at(index)
		var descendant := closest_subset_cards_acc(remaining, target, candidate_value, candidate)
		if !descendant.is_empty() and (best.is_empty() or Player.cards_value(descendant) < Player.cards_value(best)):
			best = descendant
	return best
