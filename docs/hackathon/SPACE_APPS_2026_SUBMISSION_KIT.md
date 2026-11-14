# NASA Space Apps 2026 — AgriGuardian Submission Kit

Challenge: [Field Shift: Adapting Farms with NASA Data](https://www.spaceappschallenge.org/2026/challenges/field-shift-adapting-farms-with-nasa-data/)

## High-level summary (safe draft)

AgriGuardian is a bilingual, farmer-centered prototype for exploring crop rotation options across Bangladesh. It combines region-specific crop calendars and FAO crop suitability evidence with NASA climate context, soil information and farmer-selected priorities. It compares feasible cropping sequences, displays evidence sources, and explains irrigation and calendar constraints. When evidence is insufficient, it warns or abstains instead of making unsupported yield or profit promises.

**Accuracy note:** The current scenario-ranking engine uses BAMIS crop calendars/water and GAEZ suitability; NASA POWER and SoilGrids are currently **context**, not ranking variables. Update this statement only after code and tests prove otherwise.

## 30-second video storyboard (edit to match actual on-screen evidence)

| Seconds | Visual | Narration (short) |
|---|---|---|
| 0–5 | Farmer choosing season on a field | "Changing rainfall makes crop rotation decisions harder for farmers." |
| 5–10 | Choose a Bangladesh district, irrigation and preference | "AgriGuardian brings local crop calendars and Earth observation context together." |
| 10–17 | Show an actual computed scenario and alternative | "It compares feasible crop sequences against calendar and water constraints." |
| 17–23 | Open a real claim with original source and limitation | "Every recommendation explains its evidence and what remains unknown." |
| 23–28 | Show climate context and no-irrigation comparison | "Farmers can explore scenarios without false yield promises." |
| 28–30 | Project title and public project URL | "AgriGuardian: decisions with evidence." |

**Do not render any scene that the functioning prototype cannot actually demonstrate.** The visuals above are a production plan, not proof that the user flow was executed.

## Alternative: seven-slide outline

1. Problem and farmers affected (no unsourced impact number).
2. Field Shift objective and why NASA Earth observations matter.
3. User journey: location → preferences → comparable scenarios.
4. Transparent architecture: NASA climate **context**, BAMIS calendar/water, GAEZ suitability, SoilGrids **context**.
5. Real Rajshahi and Sylhet scenarios with source-linked explanations and explicit scale limitations.
6. Audit evidence, known missingness, refusal to invent unsupported recommendations.
7. Clear conclusion: current prototype strengths, limitations and research validation roadmap.

## Submission verification

- [ ] Project title, short summary, longer description and public final-project link.
- [ ] Publicly viewable **short demo link** meeting the 30-second-or-seven-slides requirement.
- [ ] NASA dataset URLs, non-NASA data sources, attribution and product/date/resolution metadata.
- [ ] AI tools and any generated imagery correctly disclosed; brand guide followed.
- [ ] All existing/pre-event work and organizer permission handled under actual 2026 eligibility rules.
- [ ] Anonymous-browser test of every link, no login wall for the judge's required resources.
- [ ] Facts in video exactly match the live demo; no synthetic outcomes presented as measured performance.
- [ ] Submission completed on official Team → Project page before deadline.

### Reference URLs

- 2026 event: https://www.spaceappschallenge.org/2026/
- Submission guide: https://www.spaceappschallenge.org/resources/project-submission-guide
- Brand guide: https://www.spaceappschallenge.org/brand/
- NASA POWER: https://power.larc.nasa.gov/docs/services/api/temporal/daily/
- BAMIS/DAE: https://www.bamis.gov.bd/
- FAO GAEZ: https://gaez.fao.org/
- SoilGrids: https://soilgrids.org/
