# Home & balance

**Status:** Partly built. The layout, balance mood, home currency and the Squabbles tile
are done. Totals convert into the home currency.

## Summary

Home is the app's root screen: the user's avatar (opens the account page), search, a `+`
to start a squabble, and the **total balance**, which is the net of everything owed in
either direction. There's no tab bar; squabbles are pushed from home like conversations.

## Decisions

- **No tab bar** (Oct 2026). Add a `TabView` only once there are 3 or more peer
  destinations.
- **The account page is pushed, not a sheet** (Oct 2026). Its photo picker and payment
  editor would otherwise stack a sheet on a sheet.

## Total balance

- **Positive** means others owe the user; **negative** means the user owes others.
- Shown in the **home currency**, labelled "Total · <code>".
- **Built (Nov 2026):** the sum of the user's stored balances, with other currencies converted
  at the ECB's latest daily rates (`HomeTotal`, `RatesStore`; see
  [Bills](bills.md#exchange-rates)). Added up exactly and rounded once. Display only: what
  people owe stays in each squabble's currency.
- A converted total isn't marked as approximate (an "≈" was tried and dropped, Nov 2026).
- It's centred between the toolbar and the first tile.
- A currency without a rate is listed under the total instead of guessed. Before any rates have
  arrived that's all of them, except that a lone balance in another currency is the headline
  rather than a zero.

## Balance mood

The backdrop colour reflects the balance (`BalanceMood`). The hue shows which way the
money flows; the saturation shows how much.

| Balance | Colour |
| --- | --- |
| Zero | Petrol (`#1A6670`) |
| Owed, small → large | Pale green → brand green |
| Owing, small → large | Amber → red |

- **Intensity** runs from −1 to 1 on a log scale, so €5, €50 and €250 each read as a
  real step. It reaches full strength at about **€250**.
- Pale green is fully in at about **€6** owed. Amber is fully in at about **€1** owing:
  the midpoint between petrol and amber is a muddy khaki, so debts pass through it
  quickly.
- Amounts are judged in euros at the latest rates. A small rough table
  (`BalanceMood.unitsPerEuro`, e.g. HUF 400) stands in until there are some, or for a currency
  without one.
- This is the one place `Double` is allowed near money: it only picks a colour and never
  changes an amount.

### Where the mood shows

A bright fade always stands for a balance; pages without one stay quiet (Nov 2026).

| Page | Backdrop |
| --- | --- |
| Home | Bright band from the top: the total balance |
| Squabbles list | Plum in slow waves (`QuietBackdrop`), a hue no mood uses; dark petrol looked too much like the other pages. Each row's picture has a ring in its squabble's mood, here and on home, unless it's settled |
| Squabble page | Wavy glow from the top-right corner (a clean diagonal felt too rigid), by the picture: the balance in that squabble |
| Squabble info | The same glow, dimmed |
| Account pages and sheets | Dark brand green (`ProfileBackdrop`) |

The squabble glow doesn't run bottom to top: the newest messages and the composer would
sit on the brightest part, and the keyboard would cover it.

## Tiles

Below the balance, home is a column of **tiles** (`HomeTile`), laid out like Revolut's
home (Nov 2026): a card with its title inside at the top left in a quiet colour, then its
rows. Rows have a 48 pt picture, a title and a grey subtitle, and no chevron.

- **Squabbles** (built): the squabbles the user is in, newest activity first. Each row
  shows the picture, the name, "N members · CODE" and the last activity date; tapping it
  pushes the squabble.
  Only the **3 most recently active** show. The title has a chevron, and a **See all** row
  closes the card; both push the full list (see [Groups](groups.md#squabble-pages)).
  The user's balance in it shows on the right unless it's zero.
- **Empty:** a dove, "No squabbles yet", a joke about the peace, and a white **Start a
  squabble** button that zooms the create sheet out of itself (as `+` does).
- The tile stays hidden until the first answer from Firestore, so a returning user never
  sees the empty state flash.

**Tile ideas, undecided** (Nov 2026), roughly by value, all waiting on bills: **You owe /
Owed to you** (the people behind the total, with nudge and pay), **Expenses** (recent bills
across squabbles), **People** (a net balance per person), **Activity**. No quick-action row
like Revolut's: `+` already covers the one main action.

## Home currency

- Stored in `users/{uid}/private/preferences` as `homeCurrency` (an ISO 4217 code).
  Only the owner can read it.
- **Unset means "follow the device"**: `Locale.current.currency`, taken from the phone's
  **Region** setting rather than its language, and falling back to EUR. It's resolved
  when read, so moving abroad updates the default. The field is only written once the
  user picks a currency, and choosing "follow device" clears it.
- The picker lists `Locale.commonISOCurrencyCodes`, sorted by localized name. Search
  matches the code, the name or the country, ignoring case and accents.
- **Flags:** a currency's country is the region its code starts with (HUF → HU,
  EUR → EU), or otherwise the only region that uses it. Currencies shared by several
  countries show a banknote instead. A test fails if a mapped flag asset is missing.
- It's the currency home's total is converted into.

## Placeholders and built entry points

- **Search:** no destination yet. Likely becomes search across squabbles and
  [people](people.md).
- **`+`** opens the create-squabble sheet (see [Groups](groups.md)).
