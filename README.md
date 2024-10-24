# 🔥 WinMasterBlocker 🔥

### Your all-in-one firewall control script for blocking Adobe, Autodesk, Corel, FL Studio, and more! 💻🚫

## What is this?

Welcome to **WinMasterBlocker**—a nifty little batch script that slaps firewall rules on apps you probably don’t want connecting to the internet (like Adobe, Corel, Autodesk, FL Studio, and others). It’s your no-fuss way to get peace and quiet from those phoning-home apps. 🚫📡

💡 **TL;DR:** This script blocks incoming/outgoing network access for well-known apps using **Windows Firewall**. You choose the app, the script takes care of the rest using all windows inbuilt tools.

---

## Usage 📜

### Running the script:

1. **Make sure you run this as admin!** It won't work otherwise _(netsh requires it)_. We’ll prompt you if you forget, don’t worry. 😎
2. **Double-click or run from the command line**:
   - Want to block Adobe? Autodesk? Corel? We got you.
   - We also throw in FL Studio for the producers out there. 🎧

### Options in the menu:

- **Block rules** for Adobe, Corel, Autodesk, etc.
- **Remove firewall rules** (just the ones we added, don’t worry 😉).
- You can pick whether to block **inbound**, **outbound**, or both kinds of traffic. Customizable and clean. 💪

---

## Contributing 👾

We love contributions, PRs, and feature requests! If you’re one of those who likes to tinker and hack on scripts, here’s how you can get involved:

### Steps to contribute:

1. **Fork it** 🍴 – You know the drill. Fork this repo.
2. **Clone it** 🛠️ – Get the code to your local:
   ```bash
   git clone https://github.com/YOUR_USERNAME/WinMasterBlocker.git
   ```
3. **Create a branch** 🌿 – New features? Fixes? Start a new branch:
   ```bash
   git checkout -b my-cool-feature
   ```
4. **Add your magic** ✨ – Modify `WinMasterBlocker.bat` or enhance the `README.md`. Make sure your changes are 💯 legit.
5. **Push your branch** 🚀 – Send it back up:
   ```bash
   git push origin my-cool-feature
   ```
6. **Submit a Pull Request (PR)** 🤙 – We'll take it from there.

### Want to add more apps to block? 🛑

Feel free to throw in more providers. Just add the app to the `providers[]` and `paths[]` arrays in the script. Got new paths for a provider? Add them in there too! We’re open to adding pretty much anything (the bigger the blacklist, the better). 💣

```batch
:: Add new provider paths here
set "providers[9]=NewApp"
set "paths[9]=C:\Program Files\NewApp C:\Program Files (x86)\NewApp"
```

### Checklist before sending that PR 🚧:

- Make sure the script **runs on your machine** before submitting. Nobody likes broken code. 🛠️
- Follow the existing format for adding new providers or paths.
- Respect the 💀 rule: **no hard-breaking changes** (or you’ll owe us a coffee).

---

## License ⚖️

MIT License – this means you can do pretty much anything with this, but we’d love a shout-out if you find it useful. 🎉

---

## Contact 📫

- **Author:** [ph33nx](https://github.com/ph33nx)
- **Current Repo:** [WinMasterBlocker](https://github.com/ph33nx/WinMasterBlocker)
- **Contributions welcomed!** - Especially for app providers and their install locations.

---

Feel free to copy, edit, or just stare at the code. 😎
