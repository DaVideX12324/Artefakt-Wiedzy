# Quiz RPG — Edukacyjna gra top-down RPG z systemem quizów

## Opis projektu

Interaktywny system edukacyjny w formie gry top-down RPG. Warstwa merytoryczna (pytania/odpowiedzi) jest oddzielona od warstwy prezentacji — quizy ładowane z plików JSON. System wykorzystuje grywalizację (punkty, poziomy, nagrody, streak) oraz adaptacyjną trudność.

## Wymagania

- Godot 4.3+ (GL Compatibility renderer)
- Brak zewnętrznych zależności

## Struktura projektu

```
quiz-rpg/
├── autoloads/                    # Singletony (autoload)
│   ├── game_manager.gd          # Zarządzanie stanami gry, scenami, zapisem
│   ├── quiz_manager.gd          # Baza pytań, ładowanie JSON, walidacja
│   ├── player_stats.gd          # Statystyki gracza: HP, XP, punkty, nagrody
│   └── difficulty_manager.gd    # Adaptacyjna trudność per kategoria
├── scenes/
│   ├── player/
│   │   └── player.tscn          # Scena gracza
│   ├── enemies/
│   │   └── enemy.tscn           # Bazowa scena przeciwnika
│   ├── quiz/
│   │   ├── quiz_combat_ui.tscn  # UI walki quizowej
│   │   └── quiz_puzzle_ui.tscn  # UI zagadki (drzwi)
│   ├── ui/
│   │   ├── hud.tscn             # HUD (HP, XP, punkty, streak)
│   │   ├── pause_menu.tscn      # Menu pauzy
│   │   └── stats_screen.tscn    # Ekran statystyk
│   └── maps/
│       ├── main_menu.tscn       # Menu główne
│       └── world_map.tscn       # Mapa testowa
├── scripts/
│   ├── player/player.gd         # Ruch top-down 8-dir, interakcja
│   ├── enemies/enemy_base.gd    # Bazowy enemy: patrol, wykrywanie, walka
│   ├── quiz/
│   │   ├── quiz_combat_controller.gd   # Logika walki quizowej
│   │   ├── quiz_puzzle_controller.gd   # Logika zagadki (drzwi)
│   │   └── quiz_door.gd                # Drzwi blokowane quizem
│   └── ui/
│       ├── hud.gd               # Kontroler HUD
│       ├── main_menu.gd         # Menu główne
│       ├── pause_menu.gd        # Menu pauzy
│       └── stats_screen.gd      # Ekran statystyk
├── resources/
│   └── quizzes/                 # Pliki JSON z pytaniami
│       ├── informatyka.json     # 20 pytań z informatyki (trudność 1-4)
│       └── matematyka.json      # 12 pytań z matematyki (trudność 1-4)
└── project.godot                # Konfiguracja projektu
```

## Architektura

### Autoloady (Singletony)

| Singleton           | Odpowiedzialność                                    |
|---------------------|-----------------------------------------------------|
| `GameManager`       | Stany gry, tranzycje scen, zapis/odczyt             |
| `QuizManager`       | Ładowanie quizów z JSON, walidacja, statystyki      |
| `PlayerStats`       | HP, XP, level, punkty, streak, RNG bonus, nagrody   |
| `DifficultyManager` | Adaptacyjna trudność per kategoria (okno 10 odp.)   |

### Stany gry (GameManager.GameState)

```
MENU → EXPLORING → QUIZ_COMBAT / QUIZ_PUZZLE → EXPLORING
                 → PAUSED → EXPLORING
```

### Mechaniki quizowe

#### 1. Walka quizowa (QUIZ_COMBAT)
- Przeciwnik na mapie wykrywa gracza → inicjuje walkę
- Gracz odpowiada na pytania z limitem czasu (15s)
- **Poprawna odpowiedź** → obrażenia wroga + XP + punkty + streak
- **Bonus RNG** → szansa na dodatkowe obrażenia (rośnie z serią)
- **Błędna/timeout** → gracz traci HP, streak resetowany
- Wróg pokonany → XP reward, znika z mapy

#### 2. Zagadki blokujące (QUIZ_PUZZLE)
- Drzwi/przejścia na mapie wymagają poprawnych odpowiedzi
- Progress bar: np. "3/5 poprawnych" żeby otworzyć
- Bonus RNG → szansa na +1 do progresu
- Po otwarciu kolizja wyłączona, drzwi przezroczyste

#### 3. System RNG z bonusem
- `rng_bonus` rośnie z każdą poprawną odpowiedzią w serii (+0.05 + streak×0.02)
- Maleje po błędnej odpowiedzi (-0.1)
- Max bonus: 50% dodane do bazowej szansy
- Używany do: dodatkowych obrażeń, bonusowego progresu drzwi

### Grywalizacja

- **Punkty**: 10 bazowych + streak × 5 za poprawną odpowiedź
- **XP**: 15 + streak × 3 za odpowiedź, level up = pełne HP
- **Poziomy**: wymagany XP rośnie ×1.5 per level
- **HP**: 100 bazowe + 20 per level
- **Nagrody/Achievements**: Początkujący Uczeń, Pilny Student, Mistrz Wiedzy, Serie, Poziomy

### Adaptacyjna trudność

- Okno ostatnich 10 odpowiedzi per kategoria
- \>80% poprawnych → trudność +1
- <40% poprawnych → trudność -1
- Zakres 1-5, domyślnie 2
- QuizManager filtruje pytania wg zakresu trudności (bazowa ±1)

## Format pliku JSON z quizami

```json
{
  "name": "Nazwa quizu",
  "description": "Opis",
  "questions": [
    {
      "id": "unikalne_id",
      "question": "Treść pytania",
      "answers": ["Odp A", "Odp B", "Odp C", "Odp D"],
      "correct_index": 0,
      "difficulty": 1,
      "category": "nazwa_kategorii",
      "explanation": "Opcjonalne wyjaśnienie"
    }
  ]
}
```

## Sterowanie

| Klawisz     | Akcja                          |
|-------------|--------------------------------|
| WASD / ←↑↓→ | Ruch gracza                   |
| E           | Interakcja (NPC, drzwi, wrogi) |
| ESC         | Pauza                          |

## Jak dodać nowy quiz

1. Utwórz plik `.json` w `resources/quizzes/`
2. Użyj formatu powyżej
3. W scenie ustaw `quiz_id` wroga/drzwi na nazwę pliku (bez .json)
4. Ustaw `quiz_category` na kategorię pytań

## Co trzeba jeszcze zrobić (MVP)

- [ ] Dodać sprite'y gracza (AnimatedSprite2D z animacjami walk_up/down/left/right, idle_up/down/left/right)
- [ ] Dodać sprite'y wrogów
- [ ] Dodać sprite/teksturę drzwi quizowych
- [ ] Dodać TileMap na mapie świata
- [ ] CollisionShape2D dla drzwi i ścian
- [ ] Dodać dźwięki (poprawna/błędna odpowiedź, walka, level up)
- [ ] Opcjonalnie: theme/skin dla UI (Panel, Button)
- [ ] Więcej plików JSON z pytaniami
