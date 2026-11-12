/// Ready-made questions for Ask Gemini, one tap each.
class GeminiPrompt {
  const GeminiPrompt(this.emoji, this.label, this.prompt);
  final String emoji;
  final String label;
  final String prompt;
}

const kGeminiPrompts = [
  GeminiPrompt(
    '🍳',
    'New recipes from my inventory',
    'Suggest 3 new recipes I can make mostly from what is in our '
        'inventory, using what goes off soonest first and following our '
        'family notes. For each: the dish, time needed, what we have, and '
        'what is missing. Offer to put the missing items on the shopping '
        'list.',
  ),
  GeminiPrompt(
    '⏰',
    'Use up what is expiring',
    'What in our inventory goes off in the next 3 days, and how can we use '
        'it up? Quick ideas, and offer to put a dish on the meal plan.',
  ),
  GeminiPrompt(
    '📈',
    'New things to try (trends)',
    'Search what is trending in German supermarkets and food right now '
        '(new products, seasonal produce). Suggest 5 things we might like '
        'to try, based on our family notes and what we usually have. Offer '
        'to add them to the shopping list.',
  ),
  GeminiPrompt(
    '🗓️',
    'Plan this week\'s dinners',
    'Plan dinners for the rest of this week. Use our inventory first, keep '
        'busy days (see the calendar) quick, follow our family notes. Offer '
        'to put each dinner on the meal plan and the missing ingredients on '
        'the shopping list.',
  ),
  GeminiPrompt(
    '🛒',
    'What should I buy this week?',
    'Looking at our inventory, shopping list, meal plan and family notes, '
        'what are we missing for this week? Offer to add it to the shopping '
        'list.',
  ),
  GeminiPrompt(
    '🥗',
    'Healthier and more protein',
    'Looking at our inventory by group (protein, carbs, other), are we '
        'balanced? Suggest healthier swaps and easy protein sources we '
        'could add, and offer to put them on the shopping list.',
  ),
  GeminiPrompt(
    '🧹',
    'Chores for the weekend',
    'What chores are due or overdue, and what else should we do this '
        'weekend? Split them fairly between us and offer to add any new '
        'ones.',
  ),
  GeminiPrompt(
    '👥',
    'Who is free this week?',
    'Looking at the calendar for the next 7 days, when are we both free, '
        'and which days are busy? Suggest good slots for shopping and '
        'cooking.',
  ),
  GeminiPrompt(
    '💶',
    'Bills coming up',
    'Which bills are due in the next 30 days, how much in total, and is '
        'anything not on auto-pay?',
  ),
];
