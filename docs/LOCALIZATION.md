# Interface languages

Aurelia 0.7.0 supports Traditional Chinese (`zh_TW`) and English (`en`). Select a language from the title or pause screen; it is stored separately from character saves in `user://preferences.cfg`. Each multiplayer client chooses its own language. No translated strings are used as network IDs or character profile values.

`scripts/language.gd` is the `Language` autoload. It loads `translations/en.json`, translates exact source strings, formats numeric status messages and resolves composed place names. A bounded cache avoids repeatedly processing unchanged HUD text. Existing Label3D nodes retain their source text and refresh when the locale changes. Player-entered names bypass localization.

Traditional Chinese source text remains the canonical fallback. Keep English catalog keys identical to source strings and preserve printf placeholders, including their order, width and precision. Spell descriptions wrap after translation, and controls fit text to their available width. Original license documents are displayed unchanged in the credits view.

Validation:

```sh
python3 tools/check_translations.py
godot --headless --path . --script tests/language_test.gd
python3 tools/test_network.py --languages
```

The runtime test checks exact and formatted strings, generated town/dungeon names, existing world labels, player-name preservation, preferences and unchanged character state. The multiplayer test runs English and Chinese clients in the same server. `tests/language_review.gd` captures both title screens and English character creation, gameplay, spellbook, journal, map, pause, credits and dialogue for visual review.
