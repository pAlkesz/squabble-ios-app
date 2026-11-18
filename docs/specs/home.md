# Home & balance

**Status:** Partly built. The layout, balance mood and home currency are done. The balance
is a fixed 0 and the squabble list doesn't exist until groups land.

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
- **Planned:** the sum across all squabbles, converted into the home currency. Nothing
  converts yet. It will use the ECB's daily rates (see
  [Bills](bills.md#exchange-rates)).

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
- Amounts are judged in rough euro terms using a small per-currency table
  (`BalanceMood.unitsPerEuro`, e.g. HUF 400, JPY 160). This is a colour heuristic, not an
  exchange rate. Replace it with real rates once totals convert.
- This is the one place `Double` is allowed near money: it only picks a colour and never
  changes an amount.

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
- **Today it only relabels the total.** Nothing is converted.

## Placeholders

- **Search:** no destination yet. Likely becomes search across squabbles and
  [people](people.md).
- **`+`:** will open the new-squabble flow (see [Groups](groups.md)).
