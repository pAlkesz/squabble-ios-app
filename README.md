# Squabble 🐦🧾

> Split the bill before it turns into a squabble.

**Squabble** is a native iOS bill splitter that uses AI to figure out who owes what — and then helps you deliver the bad news with just the right amount of passive-aggressive flair.

This is a personal project and a bit of a joke app. It's meant to be playful. Do not use it to settle a mortgage.

## The idea

You go out. Someone orders the lobster. Someone "just had a salad" but also three cocktails. Somebody paid, somebody Venmo'd half, and now there's a group chat with 47 unread messages.

Squabble is here to help:

- 📸 Snap a photo of the receipt, or type items in by hand
- 🤖 AI parses the receipt and suggests a fair split
- 🧠 Assign items to people, split shared stuff, handle tax & tip
- ✉️ Generate a friendly (or not-so-friendly) reminder message for whoever owes you
- 📊 See who's the most expensive friend to hang out with

## Status

Very early. Right now this is a fresh SwiftUI project that says "Hello, world!" — the squabbling has not yet been implemented.

### Roadmap (aspirational, subject to vibes)

- [ ] Receipt entry (manual)
- [ ] Receipt scanning + AI line-item parsing
- [ ] People & item assignment
- [ ] Tax / tip / shared-item math
- [ ] Split summary + settle-up
- [ ] AI-generated reminder messages with adjustable pettiness
- [ ] Friend leaderboard

## Tech

- Swift 6 / SwiftUI
- iOS 26+ (native), iPhone & iPad
- Some AI model for receipt parsing and message generation (TBD)

## Building

Open `squabble.xcodeproj` in Xcode and run. That's it for now.

## License

TBD. It's a meme app, please be cool.
