# Payment details

**Status:** Built (private to the owner; sharing into groups is planned)

## Summary

A user can save up to **5** ways to get paid back: bank accounts and payment links from an
allow-listed set of providers. They're shown to people who owe the user money, so they
know where to send it.

## Storage and privacy

- Stored in `users/{uid}/private/payment` as `{ methods: [...] }`. **Only the owner can
  read it.**
- **Planned:** when groups exist, the details are copied into the user's entry in each
  group's `members` map, so group-mates can read them (see [Groups](groups.md)).
- IBANs are GDPR personal data. They're deleted with the account and declared as
  "Financial Info" on the App Store privacy label.
- **Card numbers are never stored.**

## Bank accounts

Stored as an **IBAN** (upper case, no spaces) plus the **account holder's name**.

**Input** (`IBAN(validatingAccountNumber:)`):

- If the input starts with a letter, it's treated as an IBAN from any country: 15–34
  characters, a country code, 2 check digits, and the **ISO 13616 mod-97 check**. The
  check catches typos and swapped digits, but can't tell whether the account exists.
- If it starts with a digit, it's treated as a **Hungarian domestic account number**:
  16 or 24 digits in blocks of 8, where each part has its own check digit (weights 9, 7,
  3, 1). It's converted exactly into a `HU` IBAN: a 16-digit number is padded with eight
  zeros, and the mod-97 check digits are computed.
- Spaces and hyphens are ignored.

**Display:** readers in Hungary see a Hungarian IBAN in the domestic format
(`12345678-12345678[-12345678]`, with the padding dropped). Everyone else sees the IBAN in
groups of four.

## Payment links

- Providers are allow-listed: **Revolut**, **PayPal**, **Wise**.
- Stored as **provider + username**, never as a URL. The link is rebuilt from the
  username, so a profile can never send people to an arbitrary site.
- Accepted input: a bare `username`, `@username`, or a pasted link for that provider
  (`https://revolut.me/x`, `paypal.me/x`, `paypal.com/paypalme/x`, `wise.com/pay/me/x`).
  Anything after the username, such as a PayPal.me amount, is dropped. A link from a
  different provider is rejected.
- The username is 2–40 characters from `A–Z a–z 0–9 _ - .`.

| Provider | Rebuilt link |
| --- | --- |
| Revolut | `https://revolut.me/{username}` |
| PayPal | `https://paypal.me/{username}` |
| Wise | `https://wise.com/pay/me/{username}` |

## Limits

- At most **5** methods (enforced in the app and in the rules).
- Order is kept. The first method is the one shown on the membership card.
