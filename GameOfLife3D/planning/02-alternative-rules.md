# Feature: Alternative Rule Presets

## Overview

Allow users to select different cellular automaton rule sets beyond the standard Conway B3/S23 rules. This dramatically expands the variety of patterns and behaviors users can explore.

## Motivation

- Different rules produce vastly different emergent behaviors
- Some rules have unique phenomena (replicators, chaos, stability)
- Educational value in comparing rule behaviors
- Popular feature request in cellular automaton communities
- Enables exploration of "Life-like" cellular automata

## Rule Notation

Rules use "B/S" (Birth/Survival) notation:
- **B** (Birth): Number of neighbors that cause a dead cell to become alive
- **S** (Survival): Number of neighbors that allow a live cell to survive

Example: B3/S23 means:
- Dead cell with exactly 3 neighbors becomes alive
- Live cell with 2 or 3 neighbors survives
- All other live cells die

## Proposed Rule Presets

| Name | Rule | Description |
|------|------|-------------|
| Conway's Life | B3/S23 | Classic, balanced chaos and order |
| HighLife | B36/S23 | Has replicators! |
| Day & Night | B3678/S34678 | Symmetric, interesting patterns |
| Seeds | B2/S | Explosive, chaotic growth |
| Life without Death | B3/S012345678 | Cells never die, grows forever |
| Diamoeba | B35678/S5678 | Amoeba-like growth patterns |
| 2x2 | B36/S125 | Block-based patterns |
| Morley | B368/S245 | "Move" rule, interesting oscillators |
| Anneal | B4678/S35678 | Tends toward large blobs |
| Custom | User-defined | Enter any B/S rule |

## Current Implementation

In `GameEngine.ts`, rules are hardcoded:

```typescript
private computeNextGeneration(currentGen: Generation): Generation {
    // ...
    if (isAlive) {
        nextGrid[x][y] = neighbors === 2 || neighbors === 3;  // S23
    } else {
        nextGrid[x][y] = neighbors === 3;  // B3
    }
    // ...
}
```

## Proposed Changes

### 1. GameEngine.ts

Add rule configuration:

```typescript
interface Rule {
    name: string;
    birth: number[];    // Neighbor counts that cause birth
    survival: number[]; // Neighbor counts that allow survival
}

// Preset rules
const RULE_PRESETS: Record<string, Rule> = {
    'conway': { name: "Conway's Life", birth: [3], survival: [2, 3] },
    'highlife': { name: 'HighLife', birth: [3, 6], survival: [2, 3] },
    'daynight': { name: 'Day & Night', birth: [3, 6, 7, 8], survival: [3, 4, 6, 7, 8] },
    'seeds': { name: 'Seeds', birth: [2], survival: [] },
    'lifewithoutdeath': { name: 'Life without Death', birth: [3], survival: [0, 1, 2, 3, 4, 5, 6, 7, 8] },
    'diamoeba': { name: 'Diamoeba', birth: [3, 5, 6, 7, 8], survival: [5, 6, 7, 8] },
    '2x2': { name: '2x2', birth: [3, 6], survival: [1, 2, 5] },
    'morley': { name: 'Morley', birth: [3, 6, 8], survival: [2, 4, 5] },
    'anneal': { name: 'Anneal', birth: [4, 6, 7, 8], survival: [3, 5, 6, 7, 8] },
};

class GameEngine {
    private birthRule: Set<number> = new Set([3]);
    private survivalRule: Set<number> = new Set([2, 3]);
    private currentRuleName: string = 'conway';

    public setRule(ruleKey: string): void {
        const rule = RULE_PRESETS[ruleKey];
        if (rule) {
            this.birthRule = new Set(rule.birth);
            this.survivalRule = new Set(rule.survival);
            this.currentRuleName = ruleKey;
        }
    }

    public setCustomRule(birth: number[], survival: number[]): void {
        this.birthRule = new Set(birth);
        this.survivalRule = new Set(survival);
        this.currentRuleName = 'custom';
    }

    public getCurrentRule(): string {
        return this.currentRuleName;
    }

    public getRuleString(): string {
        const b = Array.from(this.birthRule).sort().join('');
        const s = Array.from(this.survivalRule).sort().join('');
        return `B${b}/S${s}`;
    }

    // Updated generation logic
    private computeNextGeneration(currentGen: Generation): Generation {
        // ...
        if (isAlive) {
            nextGrid[x][y] = this.survivalRule.has(neighbors);
        } else {
            nextGrid[x][y] = this.birthRule.has(neighbors);
        }
        // ...
    }
}
```

### 2. UIControls.ts

Add rule selector dropdown and custom rule input:

```typescript
private createRuleSelector(): void {
    const container = document.getElementById('rule-selector-container');

    // Preset dropdown
    const select = document.createElement('select');
    select.id = 'rule-preset';

    Object.entries(RULE_PRESETS).forEach(([key, rule]) => {
        const option = document.createElement('option');
        option.value = key;
        option.textContent = `${rule.name} (B${rule.birth.join('')}/S${rule.survival.join('')})`;
        select.appendChild(option);
    });

    // Custom option
    const customOption = document.createElement('option');
    customOption.value = 'custom';
    customOption.textContent = 'Custom...';
    select.appendChild(customOption);

    select.addEventListener('change', () => {
        if (select.value === 'custom') {
            this.showCustomRuleInput();
        } else {
            this.gameEngine.setRule(select.value);
            this.onRuleChange();
        }
    });
}
```

### 3. index.html

Add rule selector in Simulation Settings:

```html
<div class="control-group">
    <label for="rule-preset">Rule Set:</label>
    <select id="rule-preset">
        <option value="conway">Conway's Life (B3/S23)</option>
        <option value="highlife">HighLife (B36/S23)</option>
        <!-- ... more presets ... -->
        <option value="custom">Custom...</option>
    </select>
</div>

<div id="custom-rule-input" class="control-group" style="display: none;">
    <label>Custom Rule:</label>
    <input type="text" id="custom-birth" placeholder="Birth (e.g., 3)">
    <input type="text" id="custom-survival" placeholder="Survival (e.g., 23)">
    <button id="apply-custom-rule">Apply</button>
</div>
```

## UI Placement

Place in "Simulation Settings" panel, above or below Grid Size:

```
Simulation Settings
-------------------
Grid Size: [dropdown]
Rule Set:  [Conway's Life (B3/S23) v]
[x] Toroidal Wrapping
```

When "Custom..." is selected, show additional inputs.

## Behavioral Notes

1. **Recomputation**: Changing rules should clear computed generations and recompute from initial state (or prompt user)

2. **Pattern compatibility**: Many patterns are designed for specific rules. Consider showing a warning when loading a pattern designed for a different rule

3. **Session persistence**: Include rule in saved sessions

4. **Display**: Show current rule string (e.g., "B3/S23") in the status bar

5. **Seeds rule warning**: Seeds (B2/S) is explosive - may want to warn users about rapid growth

## Testing Checklist

- [ ] All preset rules load correctly
- [ ] Custom rule input validates input (only digits 0-8)
- [ ] Switching rules recomputes generations
- [ ] HighLife replicator works (test pattern needed)
- [ ] Seeds shows explosive growth
- [ ] Life without Death never has cells die
- [ ] Rule persists in saved sessions
- [ ] Rule displays in status bar

## Effort Estimate

- **Code changes**: ~80 lines
- **Files modified**: 3 (GameEngine.ts, UIControls.ts, index.html)
- **Risk**: Low (rule logic is isolated)

## Future Enhancements

- Rule description tooltips
- Sample patterns for each rule
- Outer totalistic rules (more complex neighborhoods)
- Non-totalistic rules
- Generations rules (multiple states, not just alive/dead)
